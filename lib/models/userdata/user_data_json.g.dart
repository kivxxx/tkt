// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_data_json.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserDataJson _$UserDataJsonFromJson(Map<String, dynamic> json) => UserDataJson(
      account: json['account'] as String? ?? "",
      password: json['password'] as String? ?? "",
      webMailPassword: json['webMailPassword'] as String? ?? "",
    );

Map<String, dynamic> _$UserDataJsonToJson(UserDataJson instance) =>
    <String, dynamic>{
      'account': instance.account,
      'password': instance.password,
      'webMailPassword': instance.webMailPassword,
    };
