class SerialParser {
  static String extractColumns(String data, List<String> dataHistory) {
    var columns = data.split(';');
    List<String> result = [];
    String? estado;
    int aux = 0;
    bool aux2 = false;

    for (var i in columns) {
      if (i.contains('\$')) {
        aux2 = true;
      }

      if (aux2) {
        if ([1, 4, 5, 14].contains(aux)) {
          if (aux == 1) {
            String stateStr = i.trim();
            if (dataHistory.isNotEmpty) {
              // Get most common in history
              var map = <String, int>{};
              for (var h in dataHistory) {
                map[h] = (map[h] ?? 0) + 1;
              }
              var mostCommon = map.entries.reduce((a, b) => a.value > b.value ? a : b).key;
              if (mostCommon != stateStr) {
                stateStr = mostCommon;
              }
            }

            if (stateStr == '1') estado = 'charging';
            else if (stateStr == '2') estado = 'discharging';
            else if (stateStr == '4') estado = 'rest';
            else if (stateStr == '6') estado = 'finished';

            result.add(estado ?? stateStr);
          } else if (aux == 4) {
            int val = int.tryParse(i) ?? 0;
            result.add((val / 1000).toString());
          } else if (aux == 5) {
            int val = int.tryParse(i) ?? 0;
            result.add((val / 100).toString());
          } else {
            result.add(i);
          }
        }
        aux++;
      } else {
        result.add(i);
      }
    }

    return "${result.join(';')}|$estado"; // return delimited + state at end for easy unpack
  }
}
