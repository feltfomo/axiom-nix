# host side counting of executed language operations. the counts live here and
# never enter a semantic carrier, so the trace stream is the only evidence path.
use source.nu [repo-root stage-source]

const tracePrefix = "trace: AXIOM-OP "
const fields = ["n" "name" "operation" "run"]
const admittedRun = "baseline"
const rungs = [3 5 11 23 37]
const workloads = [
  "unitContext"
  "unitInference"
  "towerContext"
  "towerVariable"
  "towerProjection"
  "readback"
  "conversion"
  "oracle"
]
const operations = [
  "core.admission.attempt"
  "core.admission.node"
  "evaluation.direct.semantic-node"
  "evaluation.machine.transition"
  "logismos.computation.instruction"
  "logismos.transition.step"
  "kernel.transition.typed-neutral"
  "kernel.conversion.type"
  "kernel.conversion.term"
  "kernel.conversion.neutral"
  "kernel.conversion.oracle"
]

# a prefixed line that is not valid json is carried as an undecoded record and
# reported as an ordinary failure, so a malformed trace cannot throw past the
# staged cleanup
export def records [text: string] {
  $text
  | lines
  | where {|line| ($line | str trim) != "" }
  | where {|line| $line | str starts-with $tracePrefix }
  | each {|line|
    let payload = ($line | str substring ($tracePrefix | str length)..)
    try { { decoded: true, event: ($payload | from json) } } catch { { decoded: false, event: $payload } }
  }
}

# anything that is not an exact prefixed record is rejected rather than counted
def unrelated [text: string] {
  $text
  | lines
  | where {|line| ($line | str trim) != "" }
  | where {|line| not ($line | str starts-with $tracePrefix) }
}

# a record is only counted when its shape, types, and every closed inventory
# member match, including the single admitted run identity
export def violations [decoded: list] {
  $decoded
  | enumerate
  | each {|row|
    let item = $row.item
    if not $item.decoded {
      $"record ($row.index) is not valid json"
    } else {
      let event = $item.event
      let cols = (try { $event | columns | sort } catch { [] })
      if $cols != ($fields | sort) {
        $"record ($row.index) has fields ($cols | str join ',')"
      } else if ($event.n | describe) != "int" {
        $"record ($row.index) rung is not an integer"
      } else if ($event.name | describe) != "string" {
        $"record ($row.index) workload is not a string"
      } else if ($event.operation | describe) != "string" {
        $"record ($row.index) operation is not a string"
      } else if ($event.run | describe) != "string" {
        $"record ($row.index) run is not a string"
      } else if $event.run != $admittedRun {
        $"record ($row.index) unknown run ($event.run)"
      } else if not ($event.n in $rungs) {
        $"record ($row.index) unknown rung ($event.n)"
      } else if not ($event.name in $workloads) {
        $"record ($row.index) unknown workload ($event.name)"
      } else if not ($event.operation in $operations) {
        $"record ($row.index) unknown operation ($event.operation)"
      } else {
        null
      }
    }
  }
  | compact
}

# fixture coverage over the closed dimensions, so a stream that silently stops
# exercising a rung or a workload fails instead of reporting a smaller total
def coverage [events: list] {
  let seen = ($events | each {|event| $"($event.n)/($event.name)" } | uniq)
  let expected = ($rungs | each {|rung| $workloads | each {|leg| $"($rung)/($leg)" } } | flatten)
  {
    seen: ($seen | length)
    expected: ($expected | length)
    absent: ($expected | where {|pair| not ($pair in $seen) })
    unexpected: ($seen | where {|pair| not ($pair in $expected) })
  }
}

def measure-operations [staged: string] {
  let run = (do { ^nix eval --file $"($staged)/language-tests/kernel/operations.nix" measurement --json } | complete)
  if $run.exit_code != 0 {
    print $run.stderr
    print $"MEASURE_EXIT=($run.exit_code)"
    return 1
  }
  if ($run.stdout | str trim) != "true" {
    print $"fixture did not accept: ($run.stdout | str trim)"
    return 1
  }
  let noise = (unrelated $run.stderr)
  if ($noise | length) > 0 {
    print "unrelated stderr rejected"
    print ($noise | first 5 | str join "\n")
    return 1
  }
  let decoded = (records $run.stderr)
  let broken = (violations $decoded)
  if ($broken | length) > 0 {
    print "trace protocol rejected"
    print ($broken | first 5 | str join "\n")
    return 1
  }
  let events = ($decoded | get event)
  let pairs = (coverage $events)
  print $"total_events=($events | length)"
  print $"admitted_run=($admittedRun) distinct_pairs=($pairs.seen) expected_pairs=($pairs.expected)"
  if ($pairs.absent | length) > 0 {
    print $"missing rung and workload pairs: ($pairs.absent | str join ',')"
    return 1
  }
  if ($pairs.unexpected | length) > 0 {
    print $"unexpected rung and workload pairs: ($pairs.unexpected | str join ',')"
    return 1
  }
  print "per operation"
  print ($events | group-by operation | transpose operation events | each {|row| { operation: $row.operation, count: ($row.events | length) } })
  print "per rung and leg"
  print ($events | group-by {|e| $"($e.n)/($e.name)" } | transpose rung events | each {|row| { rung: $row.rung, count: ($row.events | length) } })
  let families = ($events | get operation | each {|o| $o | split row "." | first } | uniq)
  let nested = (["core" "evaluation" "logismos" "kernel"] | all {|family| $family in $families })
  print $"nested_families_present=($nested)"
  if not $nested { return 1 }
  return 0
}

# red when a registered mutation survives, so the kill is proved by exit status
# and not only by a green semantic suite
def measure-mutations [staged: string] {
  let run = (do { ^nix eval --file $"($staged)/language-tests/kernel/mutations/runner.nix" report --json } | complete)
  if $run.exit_code != 0 {
    print $run.stderr
    print $"MUTATION_EXIT=($run.exit_code)"
    return 1
  }
  let report = ($run.stdout | from json)
  print $"entries=($report.entries) kills=($report.kills) survived=($report.survived) installation_failures=($report.installationFailures) unexpected_failures=($report.unexpectedFailures) configuration_failures=($report.configurationFailures)"
  print ($report.results | each {|result| { name: $result.name, outcome: $result.observed.outcome } })
  if $report.configurationFailures > 0 { print "mutation case did not resolve"; return 1 }
  if $report.survived > 0 { print "mutation survived"; return 1 }
  if $report.installationFailures > 0 { print "mutation installation failed"; return 1 }
  if $report.unexpectedFailures > 0 { print "production predicate failed"; return 1 }
  if $report.kills != $report.entries { print "registry entry not executed"; return 1 }
  return 0
}

# once a staged root exists it is removed on the normal path and on a caught
# failure, so a rejected trace cannot leak a temporary tree. the original
# failure is still reported and still nonzero, and a cleanup failure is its own
# nonzero result
export def with-staged [action: closure] {
  let root = (repo-root)
  let staged = (stage-source $root)
  let outcome = (
    try {
      { status: (do $action $staged), failure: null }
    } catch {|err|
      { status: 1, failure: ($err | get msg? | default "measurement error") }
    }
  )
  let cleanup = (
    try {
      rm --recursive --force $staged
      null
    } catch {|err|
      ($err | get msg? | default "cleanup error")
    }
  )
  if $outcome.failure != null {
    print $"measurement failed: ($outcome.failure)"
  }
  print $"staged_removed=(not ($staged | path exists))"
  if $cleanup != null {
    print $"staged cleanup failed: ($cleanup)"
    print "MEASURE_STATUS=1"
    exit 1
  }
  print $"MEASURE_STATUS=($outcome.status)"
  if $outcome.status != 0 { exit $outcome.status }
}

# an unrecognised or missing mode is a configuration failure rather than a
# silent operations run
def main [mode: string = ""] {
  if $mode != "operations" and $mode != "mutations" {
    print $"unknown measurement mode ($mode)"
    print "MEASURE_STATUS=1"
    exit 1
  }
  with-staged {|staged|
    if $mode == "mutations" { measure-mutations $staged } else { measure-operations $staged }
  }
}
