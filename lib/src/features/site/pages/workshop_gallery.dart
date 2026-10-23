import 'package:flutter/material.dart';

/// A colorful opening pair and aligned gallery rows with deliberate crops.
class WorkshopGallery extends StatelessWidget {
  const WorkshopGallery({super.key, this.featured = false});
  final bool featured;
  static const photos = [
    ('painting-together.jpg', 'Painting a Mural', Alignment.center),
    (
      'student-project.jpg',
      '3-D Printable Sustainability Workshop Nametags',
      Alignment(0, -.5),
    ),
    (
      'hydroponics-workshop.jpg',
      'Spring Harbor Aquaponics Workshop',
      Alignment(-.25, 0),
    ),
    ('terrarium-workshop.jpg', 'Building Terrariums', Alignment(0, .1)),
    ('collaborative-painting.jpg', 'Painting Workshop', Alignment(0, -.35)),
    (
      'creative-workshop.jpg',
      'Hands-On Painting and Learning',
      Alignment.center,
    ),
    (
      'community-garden.jpg',
      'Solar Aquaponics at Troy Community Garden',
      Alignment.center,
    ),
    (
      'building-water-system.jpg',
      'Building the Hydroponics System Together',
      Alignment(0, .1),
    ),
    (
      'water-workshop.jpg',
      'Learning Together at an Outdoor Workshop',
      Alignment.center,
    ),
    (
      'student-terrariums.jpg',
      'Sharing Completed Terrarium Projects',
      Alignment.center,
    ),
    (
      'garden-hydroponics.jpg',
      'Aquaponics in the Community Garden',
      Alignment.center,
    ),
    (
      'hydroponics-detail.jpg',
      'Exploring Outdoor Aquaponics System',
      Alignment.center,
    ),
    (
      'classroom-group.jpg',
      'Hodgkins Elementary Earth Day Workshop',
      Alignment(0, .35),
    ),
    (
      'hydroponics-group.jpg',
      'ESW UW-Madison Collaborative Project',
      Alignment.center,
    ),
  ];

  Widget photo((String, String, Alignment) item, {double ratio = 4 / 3}) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: ratio,
              child: Image.asset(
                'assets/workshops/${item.$1}',
                fit: BoxFit.cover,
                alignment: item.$3,
                semanticLabel: item.$2,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 44,
            child: Text(
              item.$2,
              style: const TextStyle(
                fontSize: 13,
                height: 1.5,
                color: Color(0xFF667269),
              ),
            ),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 20),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final items = featured
            ? photos.take(2).toList()
            : photos.skip(2).toList();
        if (featured && constraints.maxWidth >= 560) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 2, child: photo(items[0], ratio: 3 / 2)),
              const SizedBox(width: 20),
              Expanded(child: photo(items[1], ratio: 3 / 4)),
            ],
          );
        }
        final columns = constraints.maxWidth < 500
            ? 1
            : (constraints.maxWidth < 900 ? 2 : 3);
        final width = (constraints.maxWidth - 20 * (columns - 1)) / columns;
        return Wrap(
          spacing: 20,
          runSpacing: 12,
          children: [
            for (final item in items)
              SizedBox(width: width, child: photo(item)),
          ],
        );
      },
    ),
  );
}
