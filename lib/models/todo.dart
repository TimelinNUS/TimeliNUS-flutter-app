import 'package:TimeliNUS/models/person.dart';
import 'package:TimeliNUS/models/todoEntity.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:meta/meta.dart';
import 'package:equatable/equatable.dart';

@immutable
class Todo extends Equatable {
  final bool complete;
  final String id;
  final String note;
  final String title;
  final DateTime deadline;
  final Person pic;
  final DocumentReference ref;

  const Todo(this.title,
      {this.id,
      this.complete = false,
      this.note = '',
      this.deadline,
      this.pic,
      this.ref});

  Todo copyWith(
      {String title,
      bool complete,
      String note,
      DateTime deadline,
      Person pic,
      DocumentReference ref}) {
    return Todo(title ?? this.title,
        id: id ?? this.id,
        complete: complete ?? this.complete,
        note: note ?? (this.note ?? ''),
        deadline: deadline ?? this.deadline,
        pic: pic ?? this.pic,
        ref: ref ?? this.ref);
  }

  @override
  String toString() {
    return 'Todo { complete: $complete, title: $title, note: $note, id: $id, ref: $ref}';
  }

  TodoEntity toEntity() {
    return TodoEntity(title, id, note, complete,
        deadline != null ? Timestamp.fromDate(deadline) : null, ref);
  }

  static Todo fromEntity(TodoEntity entity) {
    return Todo(entity.task,
        id: entity.id,
        complete: entity.complete ?? false,
        note: entity.note,
        deadline: entity.deadline != null ? entity.deadline.toDate() : null,
        ref: entity.ref);
  }

  @override
  List<Object> get props => [complete, id, note, title, pic, deadline];
}