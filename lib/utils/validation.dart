import 'package:flutter/material.dart';

/// Helper pour convertir les valeurs en bool avec tolérance 0/1
bool parseBool(dynamic value) {
  if (value is bool) return value;
  if (value is int) return value != 0;
  if (value is String) {
    final lower = value.toLowerCase();
    return lower == 'true' || lower == '1' || lower == 'yes';
  }
  return false;
}

/// Helper pour convertir une List en List<Map<String,dynamic>> de manière sûre
List<Map<String, dynamic>> safeCastMapList(dynamic data) {
  if (data is! List) return [];
  return data.whereType<Map<String, dynamic>>().toList();
}

/// Résultat de validation d'un champ
class ValidationResult {
  final bool isValid;
  final String? errorMessage;
  
  const ValidationResult({required this.isValid, this.errorMessage});
  
  factory ValidationResult.valid() => const ValidationResult(isValid: true);
  factory ValidationResult.invalid(String message) => ValidationResult(isValid: false, errorMessage: message);
}

/// Validateur de champ générique
typedef FieldValidator<T> = ValidationResult? Function(T value);

/// Contrôleur de champ avec validation
class ValidatedField<T> extends ChangeNotifier {
  T value;
  ValidationResult? _validationResult;
  final FieldValidator<T>? validator;
  bool _touched = false;
  
  ValidatedField({
    required this.value,
    this.validator,
  });
  
  ValidationResult? get validationResult => _validationResult;
  bool get isValid => _validationResult?.isValid ?? true;
  bool get hasError => _touched && !isValid;
  String? get errorMessage => _validationResult?.errorMessage;
  
  void updateValue(T newValue) {
    value = newValue;
    _touched = true;
    _validate();
    notifyListeners();
  }
  
  void touch() {
    _touched = true;
    _validate();
    notifyListeners();
  }
  
  void _validate() {
    if (validator != null) {
      _validationResult = validator!(value);
    }
  }
  
  void reset() {
    _touched = false;
    _validationResult = null;
    notifyListeners();
  }
}

/// Validateurs communs
class Validators {
  static FieldValidator<String> required() {
    return (String? v) {
      if (v == null || v.trim().isEmpty) {
        return ValidationResult.invalid('Ce champ est requis');
      }
      return null;
    };
  }
  
  static FieldValidator<String> minLength(int min) {
    return (String? value) {
      if (value != null && value.length < min) {
        return ValidationResult.invalid('Minimum $min caractères requis');
      }
      return null;
    };
  }
  
  static FieldValidator<String> maxLength(int max) {
    return (String? value) {
      if (value != null && value.length > max) {
        return ValidationResult.invalid('Maximum $max caractères autorisés');
      }
      return null;
    };
  }
  
  static FieldValidator<String> email(String? value) {
    return (String? v) {
      if (v == null || v.trim().isEmpty) return null;
      final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
      if (!emailRegex.hasMatch(v)) {
        return ValidationResult.invalid('Email invalide');
      }
      return null;
    };
  }
  
  static FieldValidator<num> positiveNumber(num? value) {
    return (num? v) {
      if (v == null) return null;
      if (v <= 0) {
        return ValidationResult.invalid('Doit être positif');
      }
      return null;
    };
  }
  
  static FieldValidator<num> nonNegativeNumber(num? value) {
    return (num? v) {
      if (v == null) return null;
      if (v < 0) {
        return ValidationResult.invalid('Doit être positif ou zéro');
      }
      return null;
    };
  }
  
  static FieldValidator<T> combine<T>(List<FieldValidator<T>> validators) {
    return (T value) {
      for (final validator in validators) {
        final result = validator(value);
        if (result != null && !result.isValid) {
          return result;
        }
      }
      return null;
    };
  }
}

/// Widget de champ texte avec validation intégrée
class ValidatedTextField extends StatelessWidget {
  final ValidatedField<String> field;
  final String label;
  final String? hint;
  final IconData? icon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final int? maxLines;
  final int? maxLength;
  final TextInputAction? textInputAction;
  final VoidCallback? onSubmitted;
  
  const ValidatedTextField({
    super.key,
    required this.field,
    required this.label,
    this.hint,
    this.icon,
    this.keyboardType,
    this.obscureText = false,
    this.maxLines = 1,
    this.maxLength,
    this.textInputAction,
    this.onSubmitted,
  });
  
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          initialValue: field.value,
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            prefixIcon: icon != null ? Icon(icon) : null,
            errorText: field.hasError ? field.errorMessage : null,
            counterText: maxLength != null ? '${field.value.length}/$maxLength' : null,
          ),
          keyboardType: keyboardType,
          obscureText: obscureText,
          maxLines: maxLines,
          maxLength: maxLength,
          textInputAction: textInputAction,
          onChanged: field.updateValue,
          onFieldSubmitted: (_) => onSubmitted?.call(),
        ),
      ],
    );
  }
}
