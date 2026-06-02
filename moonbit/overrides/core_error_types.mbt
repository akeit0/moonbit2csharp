pub(all) suberror BenchError {
  BenchError(String)
}

pub(all) suberror Failure {
  Failure(String)
} derive(Show)

pub(all) suberror InspectError {
  InspectError(String)
}

pub(all) suberror SnapshotError {
  SnapshotError(String)
}
