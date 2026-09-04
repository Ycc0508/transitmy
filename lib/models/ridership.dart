class Ridership {
  final String date;
  final int mrtKajang;
  final int mrtPutrajaya;
  final int lrtKelanaJaya;
  final int lrtAmpang;
  final int monorail;
  final int rapidBusKL;

  const Ridership({
    required this.date,
    required this.mrtKajang,
    required this.mrtPutrajaya,
    required this.lrtKelanaJaya,
    required this.lrtAmpang,
    required this.monorail,
    required this.rapidBusKL,
  });

  factory Ridership.fromJson(Map<String, dynamic> json) {
    return Ridership(
      date: json['date'] ?? '',
      mrtKajang: json['rail_mrt_kajang'] ?? 0,
      mrtPutrajaya: json['rail_mrt_pjy'] ?? 0,
      lrtKelanaJaya: json['rail_lrt_kj'] ?? 0,
      lrtAmpang: json['rail_lrt_ampang'] ?? 0,
      monorail: json['rail_monorail'] ?? 0,
      rapidBusKL: json['bus_rkl'] ?? 0,
    );
  }
}