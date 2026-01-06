// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'new_chat_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$NewChatState {

 ViewState get status; List<ContactItem> get contacts;
/// Create a copy of NewChatState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NewChatStateCopyWith<NewChatState> get copyWith => _$NewChatStateCopyWithImpl<NewChatState>(this as NewChatState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NewChatState&&(identical(other.status, status) || other.status == status)&&const DeepCollectionEquality().equals(other.contacts, contacts));
}


@override
int get hashCode => Object.hash(runtimeType,status,const DeepCollectionEquality().hash(contacts));

@override
String toString() {
  return 'NewChatState(status: $status, contacts: $contacts)';
}


}

/// @nodoc
abstract mixin class $NewChatStateCopyWith<$Res>  {
  factory $NewChatStateCopyWith(NewChatState value, $Res Function(NewChatState) _then) = _$NewChatStateCopyWithImpl;
@useResult
$Res call({
 ViewState status, List<ContactItem> contacts
});




}
/// @nodoc
class _$NewChatStateCopyWithImpl<$Res>
    implements $NewChatStateCopyWith<$Res> {
  _$NewChatStateCopyWithImpl(this._self, this._then);

  final NewChatState _self;
  final $Res Function(NewChatState) _then;

/// Create a copy of NewChatState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? contacts = null,}) {
  return _then(_self.copyWith(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as ViewState,contacts: null == contacts ? _self.contacts : contacts // ignore: cast_nullable_to_non_nullable
as List<ContactItem>,
  ));
}

}


/// Adds pattern-matching-related methods to [NewChatState].
extension NewChatStatePatterns on NewChatState {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _NewChatState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _NewChatState() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _NewChatState value)  $default,){
final _that = this;
switch (_that) {
case _NewChatState():
return $default(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _NewChatState value)?  $default,){
final _that = this;
switch (_that) {
case _NewChatState() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( ViewState status,  List<ContactItem> contacts)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _NewChatState() when $default != null:
return $default(_that.status,_that.contacts);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( ViewState status,  List<ContactItem> contacts)  $default,) {final _that = this;
switch (_that) {
case _NewChatState():
return $default(_that.status,_that.contacts);}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( ViewState status,  List<ContactItem> contacts)?  $default,) {final _that = this;
switch (_that) {
case _NewChatState() when $default != null:
return $default(_that.status,_that.contacts);case _:
  return null;

}
}

}

/// @nodoc


class _NewChatState implements NewChatState {
  const _NewChatState({this.status = ViewState.loading, final  List<ContactItem> contacts = const <ContactItem>[]}): _contacts = contacts;
  

@override@JsonKey() final  ViewState status;
 final  List<ContactItem> _contacts;
@override@JsonKey() List<ContactItem> get contacts {
  if (_contacts is EqualUnmodifiableListView) return _contacts;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_contacts);
}


/// Create a copy of NewChatState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$NewChatStateCopyWith<_NewChatState> get copyWith => __$NewChatStateCopyWithImpl<_NewChatState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _NewChatState&&(identical(other.status, status) || other.status == status)&&const DeepCollectionEquality().equals(other._contacts, _contacts));
}


@override
int get hashCode => Object.hash(runtimeType,status,const DeepCollectionEquality().hash(_contacts));

@override
String toString() {
  return 'NewChatState(status: $status, contacts: $contacts)';
}


}

/// @nodoc
abstract mixin class _$NewChatStateCopyWith<$Res> implements $NewChatStateCopyWith<$Res> {
  factory _$NewChatStateCopyWith(_NewChatState value, $Res Function(_NewChatState) _then) = __$NewChatStateCopyWithImpl;
@override @useResult
$Res call({
 ViewState status, List<ContactItem> contacts
});




}
/// @nodoc
class __$NewChatStateCopyWithImpl<$Res>
    implements _$NewChatStateCopyWith<$Res> {
  __$NewChatStateCopyWithImpl(this._self, this._then);

  final _NewChatState _self;
  final $Res Function(_NewChatState) _then;

/// Create a copy of NewChatState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? contacts = null,}) {
  return _then(_NewChatState(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as ViewState,contacts: null == contacts ? _self._contacts : contacts // ignore: cast_nullable_to_non_nullable
as List<ContactItem>,
  ));
}


}

// dart format on
