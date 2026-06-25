/// Horodatage en millisecondes (epoch ms).
int nowMs() => DateTime.now().millisecondsSinceEpoch;

int msFromMinutes(int minutes) => minutes * 60 * 1000;
