create or replace procedure it.prg_mig_personas_librador is

  cursor per is
    select A.COD_PERSONA,
           A.NOM_COMPLETO,
           A.TIPO,
           A.COD_USU_PROMOTOR,
           A.COD_TIP_DOCUMENTO,
           A.NRO_DOCUMENTO,
           A.COD_PAIS,
           A.DIR_CORREO,
           A.COD_ACTIVIDAD,
           A.REF_BANCARIA,
           A.REF_COMERCIAL,
           A.REF_LABORAL,
           A.REF_TARJETA,
           A.TOT_INGRESOS,
           A.ING_PRESUNTOS,
           A.EGR_PRESUNTOS,
           A.EST_VERIFICACION,
           A.COD_USU_VERIFICADOR,
           A.NOM_PER_INFORMO,
           A.OBS_VERIFICACION,
           A.FEC_VERIFICACION,
           A.TIP_RELACION,
           A.FEC_VTO_DOCUMENTO,
           A.TIP_IVA,
           A.TAS_PERSONALIZADA,
           A.RECIBE_SMS,
           A.COD_PAI_DOCUMENTO,
           A.COD_RUB_PRIMARIO,
           A.COD_RUB_SECUNDARIO,
           A.COD_RUB_TERCIARIO,
           A.MIGRA_OLA,
           A.COD_CIU_ORIGEN,
           rownum reg
      from it.mi_ba_personas_librador A
     where cod_persona not in (select cod_persona from ba_personas);

  v_error      varchar2(4000);
  v_err        varchar2(4000);
  v_ermsj      varchar2(4000);
  v_fecha      date;
  v_ult_numero number;
  v_fec        date := pag_cal.fu_obt_fec_actual(1);

begin
  delete mi_logs where proceso = 'PERSONAS_LIBRADOR';

  --Desabilitar los triggers de la tabla de personas
  sql_util.ejecute_dml('alter table BA_PERSONAS disable all triggers',
                       v_err);
  --Desabilitar los triggers de la tabla de personas fisicas
  sql_util.ejecute_dml('alter table BA_PER_FISICAS disable all triggers',
                       v_err);
  --Desabilitar los triggers de la tabla de personas juridicas
  sql_util.ejecute_dml('alter table BA_PER_JURIDICAS disable all triggers',
                       v_err);
                       
  if v_err is not null then
    raise_application_error(-20000, 'Al desabilitar triggers ' || v_err);
  end if;

  begin
    pre_ini_aplicacion;
    pae_cnf.g_cod_modulo := 1;
  end;
  
  delete mi_logs where proceso = 'PERSONAS_LIBRADOR';

  for i in per loop
    begin
      insert into it.ba_personas
        (cod_persona,
         nom_completo,
         tipo,
         cod_usu_promotor,
         cod_tip_documento,
         nro_documento,
         cod_pais,
         dir_correo,
         cod_actividad,
         tot_ingresos,
         ing_presuntos,
         egr_presuntos,
         usu_insercion,
         fec_insercion,
         usu_modificacion,
         fec_modificacion,
         est_verificacion,
         cod_usu_verificador,
         fec_verificacion,
         nom_per_informo,
         obs_verificacion,
         tip_relacion,
         fec_vto_documento,
         cod_rub_primario,
         tip_iva,
         Tas_Personalizada,
         RECIBE_SMS,
         Cod_Pai_Documento,
         Cod_Rub_Secundario,
         Cod_Rub_Terciario,
         Cod_Ciu_Origen)
      values
        (i.cod_persona,
         decode(i.nom_completo, ' ', 'DATO MIGRADO', i.nom_completo),
         i.tipo,
         i.cod_usu_promotor,
         i.cod_tip_documento,
         NVL(i.nro_documento, 'MIGRADO'),
         i.cod_pais,
         i.dir_correo,
         fug_obt_cod_actividad(I.COD_RUB_PRIMARIO),
         i.tot_ingresos,
         i.ing_presuntos,
         i.egr_presuntos,
         'MIGRA',
         v_fec,
         'MIGRA',
         v_fec,
         i.est_verificacion,
         i.cod_usu_verificador,
         i.fec_verificacion,
         i.nom_per_informo,
         i.obs_verificacion,
         i.tip_relacion,
         i.fec_vto_documento,
         i.cod_rub_primario,
         i.tip_iva,
         I.Tas_Personalizada,
         I.RECIBE_SMS,
         I.Cod_Pai_Documento,
         I.Cod_Rub_Secundario,
         I.Cod_Rub_Terciario,
         I.Cod_Ciu_Origen);
    exception
      when others then
        v_error := sqlcode;
        v_ermsj := sqlerrm;
        v_fecha := sysdate;
        insert into mi_logs
          (nro_reg, nro_error, men_error, comentario, proceso, fec_proceso)
        values
          (i.reg,
           v_error,
           v_ermsj,
           i.cod_persona || ' ' || i.cod_tip_documento || ' ' ||
           i.nro_documento || ' ' || i.nom_completo,
           'PERSONAS_LIBRADOR',
           v_fecha);
    end;
  end loop;

  --Habilitar los triggers
  sql_util.ejecute_dml('alter table ba_per_fisicas enable all triggers',
                       v_err);
  if v_err is not null then
    raise_application_error(-20000, 'Al habilitar triggers ' || v_err);
  end if;

  sql_util.ejecute_dml('alter table ba_per_juridicas enable all triggers',
                       v_err);
  if v_err is not null then
    raise_application_error(-20000, 'Al habilitar triggers ' || v_err);
  end if;

  --Habilitar los triggers de la tabla de personas
  sql_util.ejecute_dml('alter table BA_PERSONAS enable all triggers',
                       v_err);
  if v_err is not null then
    raise_application_error(-20000, 'Al Habilitar triggers ' || v_err);
  end if;
  
exception
  when others then
    v_error := sqlcode;
    v_ermsj := nvl(v_err, sqlerrm);
    v_fecha := sysdate;
    insert into mi_logs
      (nro_reg, nro_error, men_error, comentario, proceso, fec_proceso)
    values
      (1, v_error, v_ermsj, v_ult_numero, 'PERSONAS_LIBRADOR', v_fecha);
    commit;
end prg_mig_personas_librador;
/
