CREATE OR REPLACE FUNCTION IT."FUG_OBT_CAU_INHIBICION"(p_nro_cuenta  ge_cuentas.nro_cuenta%TYPE,
                                                    p_descripcion ge_causales.descripcion%type default null)
  RETURN varchar2 IS
  V_DESCRIPCION varchar2(10000);

  cursor firmantes(p_cta ge_cuentas.nro_cuenta%TYPE) is
    select a.cod_persona from ge_cta_clientes a where a.nro_cuenta = p_cta;

  cursor causal(p_per ba_personas.cod_persona%TYPE, p_descripcion ge_causales.descripcion%type) is
    select a.cod_persona,
           a.cod_causa,
           fug_obt_des_causa(a.cod_causa) as des
      from ge_per_inhibidas a, ge_causales b
     where a.cod_persona = p_per
       and a.cod_causa = b.cod_causa
       and b.descripcion like '%' || p_descripcion || '%'
       and a.estado = 'I';

Begin

  FOR FIR IN firmantes(p_nro_cuenta) LOOP
    FOR CAU IN CAUSAL(FIR.COD_PERSONA, p_descripcion) LOOP
      if CAU.COD_CAUSA >= 1 then
        V_DESCRIPCION := V_DESCRIPCION || ' *CLIENTE: ' || FIR.COD_PERSONA;
        V_DESCRIPCION := V_DESCRIPCION || ' ' || CAU.DES || ' ' ||
                         CAU.COD_CAUSA || ' -- ';
      end if;
    END LOOP;
  END LOOP;
  return v_descripcion;
END;
/

