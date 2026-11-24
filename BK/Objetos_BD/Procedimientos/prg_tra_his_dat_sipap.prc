create or replace procedure it.prg_tra_his_dat_sipap is

  ----Proyecto COREPESI-15-Proceso Automatico Historico-----------
  --Variables--
  v_fecha date;
  v_nom_tabla varchar2(2000);
  v_val_par_tiempo ge_par_dinamicos.val_parametro%type;
  v_val_tip_tiempo varchar2(1);
  v_val_can_tiempo varchar2(20);
  v_val_num_tiempo number(10);
  v_fec_cal_desde date;
  v_can_transferir number(10);
  V_msj varchar2(4000);
  v_fec_ini_his_datos date;
  v_hab_tra_historico varchar2(1);

  --Cursor--
  cursor c_tra_his_tab_sipap is
  select dominio, val_minimo, val_maximo
    from ba_cod_referencias a
   where a.dominio = 'TAB_SNP_TRA_HISTORICO'
     and a.val_maximo <> 'N';

  cursor c_tra_his_snp_men_enviados is
     select y.*
       from GE_SNP_MEN_ENVIADOS y
      where trunc(y.fec_insercion) < v_fec_cal_desde
        and trunc(y.fec_insercion) >= v_fec_ini_his_datos;


begin
  --Carga de Variables--
  v_hab_tra_historico := nvl(fug_obt_pardinamico('HAB_HIS_TRA_DAT_SIPAP'),'N');

  --Solo ejecuta si esta habilitado el Parametro dinamico--
  if nvl(v_hab_tra_historico,'N') = 'S' then
      v_fecha := pag_cal.FU_OBT_FEC_ACTUAL(1);

      BEGIN
        v_fec_ini_his_datos := TO_DATE(fug_obt_pardinamico('FEC_INI_HIS_DAT_SIPAP'),'DD/MM/YYYY');
      EXCEPTION
        WHEN OTHERS THEN
           raise_application_error(-20000, 'Error en valor de parametro FEC_INI_HIS_DAT_SIPAP. Verificar: ' || SQLERRM);
      END;
      dbms_output.put_line('Fec.Ini.His; '||to_char(v_fec_ini_his_datos,'dd/mm/yyyy'));
      --Inicia Aqui las Tablas--
      for tab in c_tra_his_tab_sipap loop
          v_nom_tabla := tab.val_minimo;--'GE_SNP_TRANSFERENCIAS';
          v_val_par_tiempo := tab.val_maximo;--fue_obt_val_max_refcodes('TAB_SNP_TRA_HISTORICO',v_nom_tabla);
          v_val_tip_tiempo := substr(v_val_par_tiempo,1,1);
          if nvl(v_val_tip_tiempo,'X') not in ('D','M') then
             raise_application_error(-20000, 'Error. En referencia '||tab.dominio||' p/tabla '||v_nom_tabla||' Tip.Tiempo: '||v_val_tip_tiempo);
          end if;
          v_val_can_tiempo := substr(v_val_par_tiempo,2);
          if fug_val_es_numerico(v_val_can_tiempo) = 'N' then
             raise_application_error(-20000, 'Error. En referencia '||tab.dominio||' p/tabla '||v_nom_tabla||' Can.Tiempo: '||v_val_can_tiempo);
          end if;
          v_val_num_tiempo := v_val_can_tiempo;

          --Verificar la fecha para el transpaso de datos--
          if v_val_tip_tiempo = 'D' then
             v_fec_cal_desde := v_fecha - v_val_num_tiempo;
          else --Cuando es M--
             v_fec_cal_desde := to_date('01'||to_char(add_months(v_fecha,(v_val_num_tiempo)*-1),'/mm/yyyy'),'dd/mm/yyyy');
          end if;
          dbms_output.put_line('Tabla; '||v_nom_tabla||chr(13)||
          'Fec.Actual: '||to_char(v_fecha,'dd/mm/yyyy')||chr(13)||
          'Parametro : '||v_val_par_tiempo||chr(13)||
          'Fec.Ca.Des: '||to_char(v_fec_cal_desde,'dd/mm/yyyy')||chr(13)||'**********');

          if v_val_par_tiempo = 'D0' then
             --Truncar la tabla pasar a historico--
             v_msj := null;
             sql_util.ejecute_dml('TRUNCATE TABLE '||v_nom_tabla, v_msj);
             if v_msj is not null then
                raise_application_error(-20000, v_msj);
             end if;
          else
              --Procesamiento de Tablas--
              if v_nom_tabla = 'GE_SNP_TRANSFERENCIAS' THEN
                 --Validar si existen datos a Transferir--
                 select nvl(count(*),0)
                   into v_can_transferir
                   from GE_SNP_TRANSFERENCIAS x
                  where trunc(x.fec_insercion) < v_fec_cal_desde
                    and trunc(x.fec_insercion) >= v_fec_ini_his_datos
                    and x.fec_valor < v_fecha
                    and not exists (select 1
                                      from GE_SNP_TRANSFERENCIAS_HIS k
                                     where k.nro_referencia = x.nro_referencia);
                 if nvl(v_can_transferir,0) > 0 then
                    --Insertar registros--
                    /*insert into GE_SNP_TRANSFERENCIAS_HIS
                    select y.*
                      from GE_SNP_TRANSFERENCIAS y
                     where trunc(y.fec_insercion) < v_fec_cal_desde
                       and trunc(y.fec_insercion) >= v_fec_ini_his_datos
                       and y.fec_valor < v_fecha
                       and not exists (select 1
                                         from GE_SNP_TRANSFERENCIAS_HIS k
                                        where k.nro_referencia = y.nro_referencia);

                    --Eliminar registros--
                    delete from GE_SNP_TRANSFERENCIAS z
                     where trunc(z.fec_insercion) < v_fec_cal_desde
                       and trunc(z.fec_insercion) >= v_fec_ini_his_datos
                       and z.fec_valor < v_fecha
                       and exists (select 1
                                     from GE_SNP_TRANSFERENCIAS_HIS k
                                    where k.nro_referencia = z.nro_referencia);*/
                                    null;
                 end if;
              elsif v_nom_tabla = 'GE_SNP_MENSAJES' THEN
                 --Validar si existen datos a Transferir--
                 select nvl(count(*),0)
                   into v_can_transferir
                   from GE_SNP_MENSAJES x
                  where trunc(x.fec_insercion) < v_fec_cal_desde
                    and trunc(x.fec_insercion) >= v_fec_ini_his_datos;
                 if nvl(v_can_transferir,0) > 0 then
                    --Insertar registros--
                    insert into GE_SNP_MENSAJES_HIS
                    select y.*
                      from GE_SNP_MENSAJES y
                     where trunc(y.fec_insercion) < v_fec_cal_desde
                       and trunc(y.fec_insercion) >= v_fec_ini_his_datos;
                    --Eliminar registros--
                    delete from GE_SNP_MENSAJES z
                     where trunc(z.fec_insercion) < v_fec_cal_desde
                       and trunc(z.fec_insercion) >= v_fec_ini_his_datos;
                 end if;
              elsif v_nom_tabla = 'SB_SNP_MENSAJES' THEN
                 --Validar si existen datos a Transferir--
                 select nvl(count(*),0)
                   into v_can_transferir
                   from SB_SNP_MENSAJES x
                  where trunc(x.fec_insercion) < v_fec_cal_desde
                    and trunc(x.fec_insercion) >= v_fec_ini_his_datos;
                 if nvl(v_can_transferir,0) > 0 then
                    --Insertar registros--
                    insert into SB_SNP_MENSAJES_HIS
                    select y.*
                      from SB_SNP_MENSAJES y
                     where trunc(y.fec_insercion) < v_fec_cal_desde
                       and trunc(y.fec_insercion) >= v_fec_ini_his_datos;
                    --Eliminar registros--
                    delete from SB_SNP_MENSAJES z
                     where trunc(z.fec_insercion) < v_fec_cal_desde
                       and trunc(z.fec_insercion) >= v_fec_ini_his_datos;
                 end if;
              elsif v_nom_tabla = 'SB_SNP_LOG_ENVIOS' THEN
                 --Validar si existen datos a Transferir--
                 select nvl(count(*),0)
                   into v_can_transferir
                   from SB_SNP_LOG_ENVIOS x
                  where trunc(x.fec_insercion) < v_fec_cal_desde
                    and trunc(x.fec_insercion) >= v_fec_ini_his_datos;
                 if nvl(v_can_transferir,0) > 0 then
                    --Insertar registros--
                    insert into SB_SNP_LOG_ENVIOS_HIS
                    select y.*
                      from SB_SNP_LOG_ENVIOS y
                     where trunc(y.fec_insercion) < v_fec_cal_desde
                       and trunc(y.fec_insercion) >= v_fec_ini_his_datos;
                    --Eliminar registros--
                    delete from SB_SNP_LOG_ENVIOS z
                     where trunc(z.fec_insercion) < v_fec_cal_desde
                       and trunc(z.fec_insercion) >= v_fec_ini_his_datos;
                 end if;
              elsif v_nom_tabla = 'GE_SNP_MEN_ENVIADOS' THEN
                 --Validar si existen datos a Transferir--
                 select nvl(count(*),0)
                   into v_can_transferir
                   from GE_SNP_MEN_ENVIADOS x
                  where trunc(x.fec_insercion) < v_fec_cal_desde
                    and trunc(x.fec_insercion) >= v_fec_ini_his_datos;
                 if nvl(v_can_transferir,0) > 0 then
                    --Insertar registros--
                    /*insert into GE_SNP_MEN_ENVIADOS_HIS
                    select y.*
                      from GE_SNP_MEN_ENVIADOS y
                     where trunc(y.fec_insercion) < v_fec_cal_desde
                       and trunc(y.fec_insercion) >= v_fec_ini_his_datos;*/
                    --  se modifica insert as select  porque ge_snp_men_enviados posee una columna LONG.
                    for cu in c_tra_his_snp_men_enviados loop
                      insert into GE_SNP_MEN_ENVIADOS_HIS(nro_referencia, situacion, cod_msj_swift,
                                                          fec_valor, msj_swift, fec_recepcion,
                                                          msj_resultado, usu_insercion, fec_insercion,
                                                          usu_modificacion, fec_modificacion, nom_archivo,
                                                          nom_pro_inserta, rev_automatico)
                           values (
                              cu.nro_referencia, cu.situacion, cu.cod_msj_swift,
                              cu.fec_valor, cu.msj_swift, cu.fec_recepcion,
                              cu.msj_resultado, cu.usu_insercion, cu.fec_insercion,
                              cu.usu_modificacion, cu.fec_modificacion, cu.nom_archivo,
                              cu.nom_pro_inserta, cu.rev_automatico);
                    end loop;
                    --Eliminar registros--
                    delete from GE_SNP_MEN_ENVIADOS z
                     where trunc(z.fec_insercion) < v_fec_cal_desde
                       and trunc(z.fec_insercion) >= v_fec_ini_his_datos;
                 end if;
              elsif v_nom_tabla = 'GE_SNP_ARCHIVO_TMP' THEN
                 delete from GE_SNP_ARCHIVO_TMP z
                  where trunc(z.fec_insercion) < v_fec_cal_desde;
              else
                 raise_application_error(-20000, 'Error. Tabla de SNP '||TAB.VAL_MINIMO||' No configurada para Traspaso a Historico');
              end if;
          end if;
      end loop;
   end if;

EXCEPTION
  WHEN OTHERS THEN
    raise_application_error(-20000, 'Error en prg_tra_his_dat_sipap: ' || SQLERRM);
end;
/

