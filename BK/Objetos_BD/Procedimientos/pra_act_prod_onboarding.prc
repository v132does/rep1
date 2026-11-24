create or replace procedure it.pra_act_prod_onboarding is
  v_cod_global  ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('COD_ENT_GLOBAL');

  cursor cta_onb is
    select t.cod_persona, p.nom_completo
      from ba_per_dat_adicionales t, ba_personas p
     where t.parametro = 'ONB_ALT_PRODUCTOS'
       and p.cod_persona = t.cod_persona
       and t.val_parametro = 'PENDIENTE'
       and p.est_verificacion = 'V'
       and not exists (select 1
                         from ah_tar_debitos td, ge_cta_clientes gc
                        where gc.cod_persona = td.cod_persona
                          and gc.relacion = 'P'
                          and td.cod_persona = t.cod_persona
                          and td.cod_ent_procesadora = v_cod_global);

  v_cod_error        number;
  v_men_error        varchar2(4000);
  v_nro_cta_ahorro   ah_cta_vistas.nro_cuenta%type;
  v_nro_cta_alcancia ah_cta_vistas.nro_cuenta%type;
  v_nro_tarjeta      ah_tar_debitos.nro_tarjeta%type;
  v_dir_mail         ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('ONB_ALT_PRO_SOPORTE');
  v_asunto           varchar2(2000) := 'Error en generación de Cuenta Bajo Riesgo (334)';
  v_txt_mail         varchar2(2000);
  v_remitente        ge_par_generales.dir_correo%type := fug_obt_dir_correo;
begin
  for i in cta_onb loop
    begin
      it.paa_alc.pr_cre_cta_ahorro(i.cod_persona,
                                   'GS',
                                   'V',
                                   v_cod_error,
                                   v_men_error,
                                   v_nro_cta_ahorro,
                                   v_nro_cta_alcancia,
                                   v_nro_tarjeta);

      if v_nro_cta_ahorro is null and v_nro_tarjeta is null then
        v_txt_mail := 'Cliente: ' || i.cod_persona || ' - ' ||
                      i.nom_completo || chr(10) || 'Proceso: Cierre de Dia' ||
                      chr(10) || 'Error: ' || v_men_error || chr(10);

        it_mail.mail(v_remitente, -- quien envia
                     v_dir_mail, -- a quien
                     v_asunto, -- asunto
                     v_txt_mail); -- detalle
      else
        --Actualizo el parametro de PENDIENTE A PROCESADO
        update ba_per_dat_adicionales
           set val_parametro = 'PROCESADO'
         where parametro = 'ONB_ALT_PRODUCTOS'
           and cod_persona = i.cod_persona;
      end if;
    exception
      when others then
        raise_application_error(-20000,
                                'Error en pra_act_prod_onboarding ' ||
                                sqlerrm);
    end;
  end loop;
end;
/

