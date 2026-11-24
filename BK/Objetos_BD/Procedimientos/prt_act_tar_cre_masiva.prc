create or replace procedure it.PRT_ACT_TAR_CRE_MASIVA is
cursor cuentas is
select g.nro_cuenta,g.nro_tarjeta,g.cod_persona from ge_cta_dat_adicionales s,ta_Tarjetas g
where s.parametro='CON_UNI_ALT_MAS'
and val_parametro='N'
and s.nro_cuenta=g.nro_cuenta
and g.vigente='S'
and g.tip_embozado is not null
and exists (select 1 from ba_per_ima_documentos b
           where b.cod_tip_documento = 64
           and b.est_doc in ('A', 'N')
           and b.cod_persona = g.cod_persona);
v_cod_pre_aprobado number(15);
v_linea_pre_aprobado  number(15);
v_nro_solicitud number(15);
v_cod_exito   number(5):=nvl(fug_obt_pardinamico('COD_MSG_EXITO'),
                                      200);
v_cod_error number(5):=nvl(fug_obt_pardinamico('COD_MSG_EXITO'),
                                      200);
v_men_error   varchar2(200):='Transaccion Exitosa';
v_nom_programa varchar2(50) := 'PRT_ACT_TAR_CRE_MASIVA';
v_estado varchar2(10):=nvl(fug_obt_pardinamico('EST_ACT_CU_TC'),'S');
begin
  Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
  for c in cuentas loop
    v_cod_error:=200;
    v_men_error:='Transaccion Exitosa';

    begin
      select nro_solicitud
      
      into v_nro_solicitud
      from ta_solicitudes
      where cod_persona=c.cod_persona
      and cod_estado='APR'
      and cod_modulo='5'
      and cod_modalidad='53'
      and cod_ent_procesadora=fug_obt_pardinamico('COD_ENT_GLOBAL');
     exception
      when others then
        v_nro_solicitud:=null;
        v_cod_error:=111;
        v_men_error:='Error al recuperar la solicitud';
        prg_ins_log_programas(v_nom_programa,
                                  substr(v_men_error,
                                         1,
                                         200),
                                  c.cod_persona,
                                  null);
    end;

     begin
         select cod_pre_aprobado,mon_lin_pre_aprobado
         into v_cod_pre_aprobado,v_linea_pre_aprobado
         from  ta_lin_pre_aprobado l
         where l.cod_persona = c.cod_persona
         and sysdate between fec_ini_oferta and fec_fin_oferta
         and estado='C';
         exception
           when others then
            v_cod_pre_aprobado:=null;
            v_linea_pre_aprobado:=null;
            v_cod_error:=222;
            v_men_error:='Error al recuperar oferta';
            prg_ins_log_programas(v_nom_programa,
                                      substr(v_men_error,
                                             1,
                                             200),
                                      c.cod_persona,
                                      null);
         end;

     if v_cod_error=v_cod_exito then
        begin
           it.pat_tgl.pr_act_lim_tar(c.nro_cuenta,
                          c.cod_persona,
                          c.nro_tarjeta,
                          v_linea_pre_aprobado,
                          v_cod_error,v_men_error);
            exception
              when others then
                v_men_error:=substr('Error al asignar limite - '||c.cod_persona||'-'||sqlerrm,1,200);
                v_cod_error:='500';
                       prg_ins_log_programas(v_nom_programa,
                                            substr(v_men_error,
                                                   1,
                                                   200),
                                            c.cod_persona,
                                            c.nro_cuenta);

          end;

            begin
               update ta_lin_pre_aprobado l
               set l.nro_solicitud  = v_nro_solicitud,
                                       l.estado         = 'A',
                                       l.fec_fin_oferta = trunc(sysdate)
               where l.cod_persona = c.cod_persona
               and l.cod_pre_aprobado=v_cod_pre_aprobado
               and sysdate between fec_ini_oferta and fec_fin_oferta
               and estado='C';
             exception
              when others then
                v_men_error:='Error al acutalizar oferta';
                prg_ins_log_programas(v_nom_programa,
                                                substr(v_men_error,
                                                       1,
                                                       200),
                                                c.cod_persona,
                                                c.nro_cuenta);
            end;
     end if;

       begin
        update ge_cta_dat_adicionales s
        set s.val_parametro=v_estado
        where s.nro_cuenta=c.nro_cuenta
        and s.parametro='CON_UNI_ALT_MAS';
        exception
          when others then
            v_men_error:='Error al acutalizar parametros';
            prg_ins_log_programas(v_nom_programa,
                                            substr(v_men_error,
                                                   1,
                                                   200),
                                            c.cod_persona,
                                            c.nro_cuenta);
       end;
       commit;
  end loop;
end;