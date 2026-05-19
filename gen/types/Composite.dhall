-- Generate Go code for PostgreSQL composite types
-- Composites are represented as structs with Scan/Value methods

let Prelude = https://prelude.dhall-lang.org/v21.1.0/package.dhall

-- Convert PostgreSQL composite name to Go type name (PascalCase)
let compositeNameToGoType : Text -> Text
    = \(compositeName : Text) ->
        -- Simple implementation: capitalize first letter
        -- In real implementation, should handle snake_case to PascalCase
        compositeName

-- Convert field name to Go field name (PascalCase)
let fieldNameToGoField : Text -> Text
    = \(fieldName : Text) ->
        -- Simple implementation: capitalize first letter
        -- In real implementation, should handle snake_case to PascalCase
        fieldName

-- Generate Go composite type definition
let generateCompositeType : Text -> List { name : Text, goType : Text, nullable : Bool } -> Text
    = \(typeName : Text) -> \(fields : List { name : Text, goType : Text, nullable : Bool }) ->
        let structFields =
            Prelude.Text.concatSep "\n\t"
                (Prelude.List.map { name : Text, goType : Text, nullable : Bool } Text
                    (\(field : { name : Text, goType : Text, nullable : Bool }) ->
                        let fieldType = if field.nullable then "*${field.goType}" else field.goType
                        in "${fieldNameToGoField field.name} ${fieldType} `db:\"${field.name}\"`")
                    fields)

        let typeDecl = ''
type ${typeName} struct {
	${structFields}
}
''

        let scanMethod = ''
// Scan implements sql.Scanner for ${typeName}
func (c *${typeName}) Scan(value interface{}) error {
	if value == nil {
		return nil
	}

	bytes, ok := value.([]byte)
	if !ok {
		return fmt.Errorf("failed to scan ${typeName}: expected []byte, got %T", value)
	}

	// Parse composite type from PostgreSQL format: (field1,field2,...)
	// This is a simplified implementation
	// Production code should use proper composite parsing
	str := string(bytes)
	if len(str) < 2 || str[0] != '(' || str[len(str)-1] != ')' {
		return fmt.Errorf("invalid composite format for ${typeName}: %s", str)
	}

	// TODO: Implement proper composite parsing
	return fmt.Errorf("composite type parsing not yet implemented for ${typeName}")
}
''

        let valueMethod = ''
// Value implements driver.Valuer for ${typeName}
func (c ${typeName}) Value() (driver.Value, error) {
	// Format composite type for PostgreSQL: (field1,field2,...)
	// This is a simplified implementation
	// Production code should use proper composite formatting
	return nil, fmt.Errorf("composite type formatting not yet implemented for ${typeName}")
}
''

        in ''
${typeDecl}

${scanMethod}

${valueMethod}
''

in  { compositeNameToGoType
    , fieldNameToGoField
    , generateCompositeType
    }
