import 'dart:typed_data';

import 'package:exif/exif.dart';
import 'package:exif/src/exifheader.dart';
import 'package:exif/src/field_types.dart';
import 'package:exif/src/tags.dart';

const int _tiffHeaderLength = 8;

Uint8List encodeExif(ExifHeader header) {
  final encoded = BytesBuilder();

  final Map<String, Map<int, IfdTag>> ifds = {
    "Image": {},
    "EXIF": {},
    "GPS": {},
    "Thumbnail": {},
    "Interoperability": {},
  };
  for (final entry in header.tags.entries) {
    ifds[entry.value.tag.ifdName]?[entry.value.tag.tag] = entry.value.tag;
  }

  bool hasExif = false;
  bool hasInterop = false;
  bool hasGps = false;
  bool hasThumbnail = false;
  if (ifds["EXIF"]!.isNotEmpty || ifds["Interoperability"]!.isNotEmpty) {
    hasExif = true;
    final exifOffsetTag = StandardTags.tags[34665]!;
    ifds["Image"]![34665] = IfdTag(
      tag: 34665,
      tagType: FieldType.long,
      printable: "",
      values: IfdInts([1]),
      tagName: exifOffsetTag.name,
      ifdName: "Image",
    );
    if (ifds["Interoperability"]!.isNotEmpty) {
      hasInterop = true;
      final interopOffset = StandardTags.tags[40965]!;
      ifds["EXIF"]![40965] = IfdTag(
        tag: 40965,
        tagType: FieldType.long,
        printable: "",
        values: IfdInts([1]),
        tagName: interopOffset.name,
        ifdName: "EXIF",
      );
    } else {
      ifds["EXIF"]!.remove(40965);
    }
  } else {
    ifds["Image"]!.remove(34665);
  }
  if (ifds["GPS"]!.isNotEmpty) {
    hasGps = true;
    final gpsOffset = StandardTags.tags[34853]!;
    ifds["Image"]![34853] = IfdTag(
      tag: 34853,
      tagType: FieldType.long,
      printable: "",
      values: IfdInts([1]),
      tagName: gpsOffset.name,
      ifdName: "Image",
    );
  } else {
    ifds["Image"]!.remove(34853);
  }
  ifds["Image"]!.remove(513);
  ifds["Image"]!.remove(514);
  if (ifds["GPS"]!.isNotEmpty) {
    hasThumbnail = true;
  }

  final imageIfd = _encodeIfd("Image", ifds["Image"]!, 0);
  final imageIfdLength = imageIfd.entries.length +
      (hasExif ? 12 : 0) +
      (hasGps ? 12 : 0) +
      4 +
      imageIfd.values.length;

  _EncodedIfd? exifIfd, gpsIfd, interopIfd, thumbnailIfd;
  int exifIfdLength = 0, gpsIfdLength = 0, interopIfdLength = 0;
  if (hasExif) {
    exifIfd = _encodeIfd("EXIF", ifds["EXIF"]!, imageIfdLength);
    exifIfdLength =
        exifIfd.entries.length + (hasInterop ? 12 : 0) + exifIfd.values.length;
  }
  if (hasGps) {
    gpsIfd = _encodeIfd("GPS", ifds["GPS"]!, imageIfdLength + exifIfdLength);
    gpsIfdLength = gpsIfd.entries.length + gpsIfd.values.length;
  }
  if (hasInterop) {
    interopIfd = _encodeIfd(
      "Interoperability",
      ifds["Interoperability"]!,
      imageIfdLength + exifIfdLength + gpsIfdLength,
    );
    interopIfdLength = interopIfd.entries.length + interopIfd.values.length;
  }
  if (hasThumbnail) {
    thumbnailIfd = _encodeIfd(
      "Thumbnail",
      ifds["Thumbnail"]!,
      imageIfdLength + exifIfdLength + gpsIfdLength + interopIfdLength,
    );
  }

  Uint8List exifOffsetField = Uint8List(0);
  Uint8List gpsOffsetField = Uint8List(0);
  Uint8List interopOffsetField = Uint8List(0);
  Uint8List thumbnailOffsetField = Uint8List(4);
  if (hasExif) {
    final exifOffsetFieldBuilder = BytesBuilder();
    final exifOffset = _tiffHeaderLength + imageIfdLength;

    exifOffsetFieldBuilder.add(_encode(
      [34665],
      size: 2,
      signed: false,
      endian: Endian.big,
    ));
    exifOffsetFieldBuilder.add(_encode(
      [FieldType.long.value],
      size: 2,
      signed: false,
      endian: Endian.big,
    ));
    exifOffsetFieldBuilder.add(_encode(
      [1],
      size: 4,
      signed: false,
      endian: Endian.big,
    ));
    exifOffsetFieldBuilder.add(_encode(
      [exifOffset],
      size: 4,
      signed: false,
      endian: Endian.big,
    ));

    exifOffsetField = exifOffsetFieldBuilder.takeBytes();
  }
  if (hasGps) {
    final gpsOffsetFieldBuilder = BytesBuilder();
    final gpsOffset = _tiffHeaderLength + imageIfdLength + exifIfdLength;

    gpsOffsetFieldBuilder.add(_encode(
      [34853],
      size: 2,
      signed: false,
      endian: Endian.big,
    ));
    gpsOffsetFieldBuilder.add(_encode(
      [FieldType.long.value],
      size: 2,
      signed: false,
      endian: Endian.big,
    ));
    gpsOffsetFieldBuilder.add(_encode(
      [1],
      size: 4,
      signed: false,
      endian: Endian.big,
    ));
    gpsOffsetFieldBuilder.add(_encode(
      [gpsOffset],
      size: 4,
      signed: false,
      endian: Endian.big,
    ));

    gpsOffsetField = gpsOffsetFieldBuilder.takeBytes();
  }
  if (hasInterop) {
    final interopOffsetFieldBuilder = BytesBuilder();
    final interopOffset =
        _tiffHeaderLength + imageIfdLength + exifIfdLength + gpsIfdLength;

    interopOffsetFieldBuilder.add(_encode(
      [40965],
      size: 2,
      signed: false,
      endian: Endian.big,
    ));
    interopOffsetFieldBuilder.add(_encode(
      [FieldType.long.value],
      size: 2,
      signed: false,
      endian: Endian.big,
    ));
    interopOffsetFieldBuilder.add(_encode(
      [1],
      size: 4,
      signed: false,
      endian: Endian.big,
    ));
    interopOffsetFieldBuilder.add(_encode(
      [interopOffset],
      size: 4,
      signed: false,
      endian: Endian.big,
    ));

    interopOffsetField = interopOffsetFieldBuilder.takeBytes();
  }
  if (hasThumbnail) {
    final thumbnailOffsetFieldBuilder = BytesBuilder();
    final thumbnailOffset = _tiffHeaderLength +
        imageIfdLength +
        exifIfdLength +
        gpsIfdLength +
        interopIfdLength;

    thumbnailOffsetFieldBuilder.add(_encode(
      [thumbnailOffset],
      size: 4,
      signed: false,
      endian: Endian.big,
    ));

    thumbnailOffsetField = thumbnailOffsetFieldBuilder.takeBytes();
  }

  encoded.add("Exif\x00\x00\x4d\x4d\x00\x2a\x00\x00\x00\x08".codeUnits);
  encoded.add(imageIfd.entries);
  encoded.add(exifOffsetField);
  encoded.add(gpsOffsetField);
  encoded.add(thumbnailOffsetField);
  encoded.add(imageIfd.values);
  if (hasExif) {
    encoded.add(exifIfd!.entries);
    encoded.add(interopOffsetField);
    encoded.add(exifIfd.values);
  }
  if (hasGps) {
    encoded.add(gpsIfd!.entries);
    encoded.add(gpsIfd.values);
  }
  if (hasInterop) {
    encoded.add(interopIfd!.entries);
    encoded.add(interopIfd.values);
  }
  if (hasThumbnail) {
    encoded.add(thumbnailIfd!.entries);
    encoded.add(thumbnailIfd.values);
  }

  return encoded.toBytes();
}

_EncodedIfd _encodeIfd(String ifdName, Map<int, IfdTag> tags, int offset) {
  final entries = BytesBuilder();
  final values = BytesBuilder();

  entries.add(_encode(
    [tags.length],
    size: 2,
    signed: false,
    endian: Endian.big,
  ));

  int entriesLength = 2 + (tags.length * 12);
  if (ifdName == "Image" || ifdName == "Thumbnail") entriesLength += 4;

  for (final tagEntry in tags.entries) {
    if (ifdName == "Image" &&
        (tagEntry.key == 34665 || tagEntry.key == 34853)) {
      continue;
    } else if ((ifdName == "EXIF") && (tagEntry.key == 40965)) {
      continue;
    }

    entries.add(_encode(
      [tagEntry.key],
      size: 2,
      signed: false,
      endian: Endian.big,
    ));
    entries.add(_encode(
      [tagEntry.value.tagType.value],
      size: 2,
      signed: false,
      endian: Endian.big,
    ));

    final tagOffset =
        _tiffHeaderLength + entriesLength + offset + values.length;
    final encodedField = _encodeField(
      tagEntry.value.values.toList(),
      tagEntry.value.tagType,
      tagOffset,
    );
    entries.add(encodedField.length);
    entries.add(encodedField.value);
    values.add(encodedField.largeValue);
  }

  return _EncodedIfd(entries.takeBytes(), values.takeBytes());
}

_EncodedField _encodeField(List<dynamic> data, FieldType type, int offset) {
  final encodedValue = BytesBuilder();
  final encodedLarge = BytesBuilder();

  if (type.name == "ASCII") {
    data = List.from(data);
    data.add(0);
  }

  int length = data.length;
  switch (type.name) {
    case "Ratio":
    case "Signed Ratio":
      encodedValue.add(_encode(
        [offset],
        size: 4,
        signed: false,
        endian: Endian.big,
      ));
      for (Ratio ratio in data) {
        final numerator = ratio.numerator;
        final denominator = ratio.denominator;
        encodedLarge.add(_encode(
          [numerator],
          size: 4,
          signed: type.isSigned,
          endian: Endian.big,
        ));
        encodedLarge.add(_encode(
          [denominator],
          size: 4,
          signed: type.isSigned,
          endian: Endian.big,
        ));
      }
      break;
    default:
      if (length <= 4 / type.length) {
        encodedValue.add(_encode(
          List<int>.from(data),
          size: type.length,
          signed: type.isSigned,
          endian: Endian.big,
        ));
        encodedValue.add(Uint8List(4 - (length * type.length)));
      } else {
        encodedValue.add(_encode(
          [offset],
          size: 4,
          signed: false,
          endian: Endian.big,
        ));
        encodedLarge.add(_encode(
          List<int>.from(data),
          size: type.length,
          signed: type.isSigned,
          endian: Endian.big,
        ));
      }
  }

  return _EncodedField(
    _encode(
      [length],
      size: 4,
      signed: false,
      endian: Endian.big,
    ),
    encodedValue.takeBytes(),
    encodedLarge.takeBytes(),
  );
}

Uint8List _encode(
  List<int> data, {
  required int size,
  required bool signed,
  required Endian endian,
}) {
  final encoded = BytesBuilder();

  for (int value in data) {
    final encodedValue = Uint8List(size);
    switch (size) {
      case 4:
        if (signed && value < 0) value += 0x100000000;
        encodedValue.buffer.asByteData().setUint32(0, value, endian);
        break;
      case 2:
        if (signed && value < 0) value += 0x10000;
        encodedValue.buffer.asByteData().setUint16(0, value, endian);
        break;
      default:
        if (signed && value < 0) value += 0x100;
        encodedValue.buffer.asByteData().setUint8(0, value);
        break;
    }

    encoded.add(encodedValue);
  }

  return encoded.toBytes();
}

class _EncodedField {
  final Uint8List length;
  final Uint8List value;
  final Uint8List largeValue;

  _EncodedField(this.length, this.value, this.largeValue);
}

class _EncodedIfd {
  final Uint8List entries;
  final Uint8List values;

  _EncodedIfd(this.entries, this.values);
}
