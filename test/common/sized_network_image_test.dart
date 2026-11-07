import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:passly/common/widgets/sized_network_image.dart';

void main() {
  test('decodes a little larger than the box on the screen', () {
    expect(
      SizedNetworkImage.decodeSize(BoxConstraints.tight(const Size(40, 40)), 3),
      180,
    );
    expect(
      SizedNetworkImage.decodeSize(
        const BoxConstraints(maxWidth: 170, maxHeight: 120),
        2,
      ),
      510,
    );
  });

  test('no size when the box is not decided', () {
    expect(SizedNetworkImage.decodeSize(const BoxConstraints(), 3), isNull);
  });
}
