CREATE OR REPLACE FUNCTION IT.FUO_SET_DOCUMENTO
 (P_TIP_DOCUMENTO BA_PERSONAS.COD_TIP_DOCUMENTO%TYPE,
  P_NRO_DOCUMENTO BA_PERSONAS.NRO_DOCUMENTO%TYPE,
  P_CON_ESPACIO   VARCHAR2 DEFAULT 'S'
 ) RETURN VARCHAR2 IS
  v_nro VARCHAR2(25);
  v_es_ci NUMBER;
BEGIN
  IF p_nro_documento IS NOT NULL THEN
    v_es_ci := 0;
    BEGIN
      v_es_ci := nvl( to_number( p_nro_documento ), 0 );
    EXCEPTION
      when others then
        v_es_ci := 0;
    END;
    IF nvl( v_es_ci, 0 ) > 0 THEN
      v_nro := ( replace( to_char( to_number( p_nro_documento ), '999,999,999,999' ), ',', '.' ) );
    ELSE
      IF ( fug_obt_tip_implementacion = 2 AND
           nvl( p_tip_documento, 1 ) = 6 ) OR -- En Bríos el código de RUC es 6
         ( fug_obt_tip_implementacion <> 2 AND
           nvl( p_tip_documento, 1 ) = 2 ) THEN -- En las demás implementaciones el código de RUC es 2
        v_nro := substr( p_nro_documento, 1, 4 ) || '-' ||
                 substr( p_nro_documento, 5, ( length( p_nro_documento ) - 5 ) );
        IF nvl( p_con_espacio, 'N' ) <> 'N' THEN
          v_nro := v_nro || ' ';
        END IF;
        v_nro := v_nro || substr( p_nro_documento, length( p_nro_documento ) );
      ELSE
        v_nro := p_nro_documento;
      END IF;
    END IF;
  ELSE
    v_nro := NULL;
  END IF;
  return ltrim( rtrim( v_nro ) );
EXCEPTION
  when others then
    return 'ERROR: ' || sqlcode;
END;
/

