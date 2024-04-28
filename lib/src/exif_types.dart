import 'dart:typed_data';

import 'package:exif/src/exifheader.dart';
import 'package:exif/src/encode_exif.dart';
import 'package:exif/src/field_types.dart';

class IfdTag {
  /// tag ID number
  final int tag;

  final FieldType tagType;

  final String tagName;

  final String ifdName;

  /// printable version of data
  final String printable;

  /// list of data items (int(char or number) or Ratio)
  final IfdValues values;

  IfdTag({
    required this.tag,
    required this.tagType,
    required this.printable,
    required this.values,
    required this.tagName,
    required this.ifdName,
  });

  @override
  String toString() => printable;
}

abstract class IfdValues {
  const IfdValues();

  List toList();

  int get length;

  int firstAsInt();
}

class IfdNone extends IfdValues {
  const IfdNone();

  @override
  List toList() => [];

  @override
  int get length => 0;

  @override
  int firstAsInt() => 0;

  @override
  String toString() => "[]";
}

class IfdRatios extends IfdValues {
  final List<Ratio> ratios;

  const IfdRatios(this.ratios);

  @override
  List toList() => ratios;

  @override
  int get length => ratios.length;

  @override
  int firstAsInt() => ratios[0].toInt();

  @override
  String toString() => ratios.toString();
}

class IfdInts extends IfdValues {
  final List<int> ints;

  const IfdInts(this.ints);

  @override
  List toList() => ints;

  @override
  int get length => ints.length;

  @override
  int firstAsInt() => ints[0];

  @override
  String toString() => ints.toString();
}

class IfdBytes extends IfdValues {
  final Uint8List bytes;

  IfdBytes(this.bytes);

  IfdBytes.empty() : bytes = Uint8List(0);

  IfdBytes.fromList(List<int> list) : bytes = Uint8List.fromList(list);

  @override
  List toList() => bytes;

  @override
  int get length => bytes.length;

  @override
  int firstAsInt() => bytes[0];

  @override
  String toString() => bytes.toString();
}

/// Ratio object that eventually will be able to reduce itself to lowest
/// common denominator for printing.
class Ratio {
  final int numerator;
  final int denominator;

  factory Ratio(int num, int den) {
    if (den < 0) {
      num *= -1;
      den *= -1;
    }

    final d = num.gcd(den);
    if (d > 1) {
      num = num ~/ d;
      den = den ~/ d;
    }

    return Ratio._internal(num, den);
  }

  Ratio._internal(this.numerator, this.denominator);

  @override
  String toString() =>
      (denominator == 1) ? '$numerator' : '$numerator/$denominator';

  int toInt() => numerator ~/ denominator;

  double toDouble() => numerator / denominator;
}

class ExifData {
  final ExifHeader? header;
  final List<String>? _warnings;

  Map<String, IfdTag> get tags {
    return header?.tags.map((key, value) => MapEntry(key, value.tag)) ?? {};
  }

  List<String> get warnings {
    return header?.warnings ?? _warnings ?? [];
  }

  Uint8List get raw {
    return header == null ? Uint8List(0) : encodeExif(header!);
  }

  ExifData(this.header) : _warnings = [];

  ExifData.withWarning(String warning)
      : _warnings = [warning],
        header = null;
}
