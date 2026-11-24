CREATE OR REPLACE FUNCTION IT.fuc_ver_inh_che_devueltos(p_nro_cuenta ge_cuentas.nro_cuenta%TYPE)
  RETURN VARCHAR2 IS
  --Cuenta de Personas Fisicas: Todos los firmantes de la cuenta conjunta deben estar inhibidos por Ley de cheques. (248,249).
  --Cuenta de Persona Juridica : Si el principal de cuenta esta inhibido por Ley.
  v_principal      ge_cta_clientes.cod_persona%TYPE;
  v_tip_persona    ba_personas.tipo%TYPE;
  v_cau_inhibicion VARCHAR2(100) := fug_obt_pardinamico('COD_CAU_INH_BLO_CTA');
  v_fec_hoy        ge_calendarios.fec_actual%TYPE := pag_cal.fu_obt_fec_actual(4);
  v_existe         VARCHAR2(1);
  v_retorno        VARCHAR2(1);
BEGIN
  --se obtiene el firmante principal de la cuenta
  v_principal := fug_obt_cli_principal(p_nro_cuenta, 'P');
  --se verifica el tipo de persona del principal
  BEGIN
    SELECT p.tipo
      INTO v_tip_persona
      FROM ba_personas p
     WHERE p.cod_persona = v_principal;
  EXCEPTION
    WHEN OTHERS THEN
      v_tip_persona := NULL;
  END;
  IF v_tip_persona = 'F' THEN
    BEGIN
      --el query busca personas que no esten inhibidos
      SELECT DISTINCT ('S')
        INTO v_existe
        FROM ge_cta_clientes cl
       WHERE NOT EXISTS (SELECT 'S'
                        FROM ge_per_inhibidas i
                       WHERE i.cod_persona = cl.cod_persona
                         AND i.estado = 'I'
                         AND instr(v_cau_inhibicion, ',' || i.cod_causa || ',') > 0
                         AND i.fec_vencimiento >= v_fec_hoy)
         AND cl.nro_cuenta = p_nro_cuenta;
    EXCEPTION
      WHEN no_data_found THEN
        v_existe := 'N';
    END;
  ELSIF v_tip_persona = 'J' THEN
    BEGIN
      --el query busca la inhibición de la persona principal
      SELECT 'S'
        INTO v_existe
        FROM ge_cta_clientes cl, ge_per_inhibidas i
       WHERE i.cod_persona = cl.cod_persona
         AND i.estado = 'I'
         AND instr(v_cau_inhibicion, ',' || i.cod_causa || ',') > 0
         AND i.fec_vencimiento >= v_fec_hoy
         AND cl.nro_cuenta = p_nro_cuenta
         AND cl.relacion = 'P';
    EXCEPTION
      WHEN no_data_found THEN
        v_existe := 'N';
    END;
  END IF;

  --cuando el princ. de la cta. es una pers. fisica se verifica que todos los firmantes se encuentren inhibidos por ley de cheques
  IF v_tip_persona = 'F' AND v_existe = 'N' THEN
    v_retorno := 'S';
  --cuando el princ. de la cta. es una pers. juridica se verifica que el principal se encuentre inhibido por ley de cheques
  ELSIF v_tip_persona = 'J' AND v_existe = 'S' THEN
    v_retorno := 'S';
  --no cumple condición
  ELSE
    v_retorno := 'N';
  END IF;

  RETURN v_retorno;
END;
/
