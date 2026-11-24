create or replace procedure it.prt_act_tip_cobros(p_nro_cuenta     in ta_cta_tarjetas.nro_cuenta%type,
                                                  p_cod_persona    in ba_personas.cod_persona%type,
                                                  p_nro_tarjeta    in ta_tarjetas.nro_tarjeta%type,
                                                  p_tip_cobro      in ta_cta_tarjetas.tip_cobro%type,
                                                  p_deb_automatico in ta_cta_tarjetas.deb_automatico%type default 'S',
                                                  p_cta_debito     in ah_tar_debitos.nro_cuenta%type,
                                                  p_cod_error      out number,
                                                  p_mensaje        out varchar) is

  v_nro_cta_tarjeta ta_cta_tarjetas.nro_cuenta%type;
  v_nro_cta_debito ah_tar_debitos.nro_cuenta%type;
  v_ent_procesadora ah_tar_debitos.cod_ent_procesadora%TYPE := fug_obt_pardinamico('COD_ENT_GLOBAL');

begin
  BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO := 1; END; 
  p_cod_error := 0;
  p_mensaje   := 'OK';
  BEGIN
    SELECT tc.nro_cuenta
      INTO v_nro_cta_tarjeta
      FROM ta_cta_tarjetas tc, ta_tarjetas t
     WHERE tc.nro_cuenta = t.nro_cuenta
       AND t.nro_tarjeta = p_nro_tarjeta
       AND t.cod_persona = p_cod_persona
       AND tc.estado != 'C';
  EXCEPTION
    WHEN no_data_found THEN
      p_cod_error := 1;
      p_mensaje   := 'No existe tarjeta asociada a la persona ' ||
                     p_cod_persona;
    WHEN OTHERS THEN 
      p_cod_error := 2;
      p_mensaje   := substr(SQLERRM, 1, 2000);
  END;
  
  if p_cta_debito is not null then
     v_nro_cta_debito := p_cta_debito;
  ELSE
    BEGIN
      SELECT td.nro_cuenta
        INTO v_nro_cta_debito
        FROM ah_tar_debitos td, ge_cuentas gc
       WHERE td.nro_cuenta = gc.nro_cuenta
         AND td.cod_persona = p_cod_persona
         AND td.tar_activa = 'S'
         AND td.cod_ent_procesadora = v_ent_procesadora
         AND gc.estado NOT IN ('A','C','T','D')
         AND rownum = 1;
    EXCEPTION
        WHEN no_data_found THEN
          p_cod_error := 3;
          p_mensaje   := 'No existe cuenta debito asociada a la persona ' ||
                         p_cod_persona;
        WHEN OTHERS THEN
          p_cod_error := 4;
          p_mensaje   := substr(SQLERRM, 1, 2000);
    END;
  end if;
  IF p_cod_error = 0 THEN
    UPDATE ta_cta_tarjetas t
       SET t.nro_cta_debito = decode(p_deb_automatico, 'S', v_nro_cta_debito, null),
           t.tip_cobro      = decode(p_deb_automatico, 'S', nvl(p_tip_cobro, 'M'), 'M'),
           t.deb_automatico = p_deb_automatico
     WHERE t.nro_cuenta = nvl(p_nro_cuenta, v_nro_cta_tarjeta);
       IF sql%notfound then
         p_cod_error := 5;
         p_mensaje   := 'No se encontraron datos a actualizar';
       end if;
  END IF;
exception
  when others then
    p_cod_error := 6;
    p_mensaje   := 'Ha ocurrido un error';
    prg_ins_log_programas('PRT_ACT_TIP_COBROS', substr(sqlerrm, 1, 4000), p_cod_persona, p_nro_cuenta);
end prt_act_tip_cobros;
/
