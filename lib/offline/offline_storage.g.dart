// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'offline_storage.dart';

// **************************************************************************
// TypeAdapter
// **************************************************************************

class OfflineFileMetadataAdapter extends TypeAdapter<OfflineFileMetadata> {
  @override
  final int typeId = 0;

  @override
  OfflineFileMetadata read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return OfflineFileMetadata(
      fileId: fields[0] as String,
      fileName: fields[1] as String,
      filePath: fields[2] as String,
      downloadedAt: fields[3] as DateTime,
      expiresAt: fields[4] as DateTime,
      serverVersion: fields[5] as int,
      sizeBytes: fields[6] as int,
      iconUrl: fields[7] as String?,
      localIconPath: fields[8] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, OfflineFileMetadata obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.fileId)
      ..writeByte(1)
      ..write(obj.fileName)
      ..writeByte(2)
      ..write(obj.filePath)
      ..writeByte(3)
      ..write(obj.downloadedAt)
      ..writeByte(4)
      ..write(obj.expiresAt)
      ..writeByte(5)
      ..write(obj.serverVersion)
      ..writeByte(6)
      ..write(obj.sizeBytes)
      ..writeByte(7)
      ..write(obj.iconUrl)
      ..writeByte(8)
      ..write(obj.localIconPath);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OfflineFileMetadataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
