import 'package:flutter/material.dart';
import 'package:ridey_app/design/ridey_theme.dart';
import 'package:ridey_app/features/places/place_search.dart';
import 'package:ridey_app/features/stations/bike_station.dart';
import 'package:ridey_app/widgets/ridey_ui.dart';

/// 지도를 옮겨 볼 곳 찾기 — 지금 있는 곳이 아니라 가려는 곳(학원·약속 장소) 근처를 미리 본다.
/// 글자를 치면 구·대여소가 바로 나오고, 검색 단추를 누르면 지명(OpenStreetMap)까지 찾는다.
class PlaceSearchPage extends StatefulWidget {
  const PlaceSearchPage({
    super.key,
    required this.stations,
    this.geocoder,
    this.title = '어디 근처를 볼까요?',
  });

  final List<BikeStation> stations;
  final PlaceGeocoder? geocoder;
  final String title;

  @override
  State<PlaceSearchPage> createState() => _PlaceSearchPageState();
}

class _PlaceSearchPageState extends State<PlaceSearchPage> {
  final _query = TextEditingController();
  late final _geocoder = widget.geocoder ?? PlaceGeocoder();
  List<SearchPlace> _local = const [];
  List<SearchPlace> _places = const [];
  var _searching = false;
  String? _placesFor;
  String? _error;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _typed(String text) {
    setState(() {
      _local = searchStations(text, widget.stations);
      if (_placesFor != text.trim()) _places = const [];
      _error = null;
    });
  }

  Future<void> _searchPlaces() async {
    final text = _query.text.trim();
    if (text.isEmpty || _searching) return;
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final found = await _geocoder.search(text);
      if (!mounted) return;
      setState(() {
        _places = found;
        _placesFor = text;
        if (found.isEmpty) {
          _error = '서울 안에서 \'$text\' 을(를) 찾지 못했어요.';
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = '지명 검색에 연결하지 못했어요. 대여소·구 이름으로 찾아 보세요.');
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.ridey;
    final results = [..._local, ..._places];
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
              child: Row(
                children: [
                  IconButton(
                    tooltip: '뒤로',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.chevron_left_rounded, size: 30),
                  ),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: TextField(
                controller: _query,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onChanged: _typed,
                onSubmitted: (_) => _searchPlaces(),
                decoration: InputDecoration(
                  hintText: '구, 대여소, 학원·역 이름',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searching
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton(
                          tooltip: '지명 검색',
                          onPressed: _searchPlaces,
                          icon: const Icon(Icons.arrow_forward_rounded),
                        ),
                ),
              ),
            ),
            if (_query.text.trim().isNotEmpty && _places.isEmpty && !_searching)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  _error ?? '학원·역 같은 지명은 검색 단추(→)를 누르면 찾아요.',
                  style: theme.textTheme.bodyMedium?.copyWith(color: c.muted),
                ),
              ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                itemCount: results.length,
                separatorBuilder: (_, _) => Divider(height: 1, color: c.line),
                itemBuilder: (context, i) {
                  final place = results[i];
                  return RideyPressable(
                    onTap: () => Navigator.of(context).pop(place),
                    semanticLabel: '${place.name} 근처 보기',
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Row(
                        children: [
                          Icon(switch (place.kind) {
                            SearchPlaceKind.district => Icons.map_outlined,
                            SearchPlaceKind.station => Icons.pedal_bike_rounded,
                            SearchPlaceKind.place => Icons.place_outlined,
                          }, color: c.muted),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  place.name,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (place.detail?.isNotEmpty == true)
                                  Text(
                                    place.detail!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: c.muted,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
