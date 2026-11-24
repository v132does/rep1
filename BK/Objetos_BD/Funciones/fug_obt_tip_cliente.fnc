CREATE OR REPLACE FUNCTION IT.fug_obt_tip_cliente(v_cod_persona IN ge_clientes.COD_PERSONA%TYPE)
  RETURN VARCHAR2 IS

  v_cod_seg_preferente ge_seg_preferentes.cod_seg_preferente%type;
  v_seg_cliente        ge_clientes.cod_seg_cliente%type;

BEGIN
  select gclie.cod_seg_preferente, gclie.cod_seg_cliente
    into v_cod_seg_preferente, v_seg_cliente
    from ge_clientes gclie
   where gclie.cod_persona = v_cod_persona;

  IF v_cod_seg_preferente is not null and v_seg_cliente is null or
     v_cod_seg_preferente is not null and v_seg_cliente is not null then
    return 'PREFERENTE';
  ELSIF v_cod_seg_preferente is null and v_seg_cliente is not null then
    IF v_seg_cliente = 28 then
      return 'EMPRESAS';
    ELSIF v_seg_cliente = 32 then
      return 'PYMES';
    ELSE
      return 'NO_PREFERENTE';
    END IF;
  ELSIF v_cod_seg_preferente is null and v_seg_cliente is null then
     return 'NO_ASIGNADO';
  END IF;
EXCEPTION
  When NO_DATA_FOUND Then
    return 'NO_ASIGNADO';
  When others then 
     raise_application_error(-20000,'FUG_OBT_TIP_CLIENTE '||sqlerrm);
END;
/

