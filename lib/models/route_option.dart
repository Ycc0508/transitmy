class RouteOption {
  final String transport;
  final String line;
  final String from;
  final String to;
  final int duration;
  final int transfers;
  final String nextArrival;
  final String followingArrival;
  final String status;

  const RouteOption({
    required this.transport,
    required this.line,
    required this.from,
    required this.to,
    required this.duration,
    required this.transfers,
    required this.nextArrival,
    required this.followingArrival,
    required this.status,
  });
}