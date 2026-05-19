-- Generate Go code for PostgreSQL enum types
-- Enums are represented as string types with constants

let Prelude = https://prelude.dhall-lang.org/v21.1.0/package.dhall

-- Convert PostgreSQL enum name to Go type name (PascalCase)
let enumNameToGoType : Text -> Text
    = \(enumName : Text) ->
        -- Simple implementation: capitalize first letter
        -- In real implementation, should handle snake_case to PascalCase
        enumName

-- Convert enum value to Go constant name
let enumValueToConstName : Text -> Text -> Text
    = \(typeName : Text) -> \(value : Text) ->
        -- Format: TypeNameValue
        -- e.g., UserRoleAdmin, UserRoleUser
        "${typeName}${value}"

-- Generate Go enum type definition
let generateEnumType : Text -> List Text -> Text
    = \(typeName : Text) -> \(values : List Text) ->
        let typeDecl = "type ${typeName} string"

        let constants =
            Prelude.Text.concatSep "\n\t"
                (Prelude.List.map Text Text
                    (\(value : Text) -> "${enumValueToConstName typeName value} ${typeName} = \"${value}\"")
                    values)

        let constBlock = ''
const (
	${constants}
)
''

        let scanMethod = ''
// Scan implements sql.Scanner for ${typeName}
func (e *${typeName}) Scan(value interface{}) error {
	if value == nil {
		*e = ""
		return nil
	}

	str, ok := value.(string)
	if !ok {
		bytes, ok := value.([]byte)
		if !ok {
			return fmt.Errorf("failed to scan ${typeName}: expected string or []byte, got %T", value)
		}
		str = string(bytes)
	}

	*e = ${typeName}(str)
	return nil
}
''

        let valueMethod = ''
// Value implements driver.Valuer for ${typeName}
func (e ${typeName}) Value() (driver.Value, error) {
	return string(e), nil
}
''

        in ''
${typeDecl}

${constBlock}

${scanMethod}

${valueMethod}
''

in  { enumNameToGoType
    , enumValueToConstName
    , generateEnumType
    }
