part of 'favorites_page.dart';

class LocalSearchPage extends StatefulWidget {
  const LocalSearchPage({super.key});

  @override
  State<LocalSearchPage> createState() => _LocalSearchPageState();
}

class _LocalSearchPageState extends State<LocalSearchPage> {
  String keyword = '';

  var animes = <FavoriteItemWithFolderInfo>[];

  late final SearchBarController controller;

  @override
  void initState() {
    super.initState();
    controller = SearchBarController(onSearch: (text) {
      keyword = text;
      animes = LocalFavoritesManager().search(keyword);
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SmoothCustomScrollView(slivers: [
        SliverSearchBar(controller: controller),
        SliverGridAnimes(
          animes: animes,
          badgeBuilder: (c) {
            return (c as FavoriteItemWithFolderInfo).folder;
          },
        ),
      ]),
    );
  }
}
