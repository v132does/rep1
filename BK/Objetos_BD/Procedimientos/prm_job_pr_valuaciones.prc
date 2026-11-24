create or replace procedure it.prm_job_pr_valuaciones is

  cursor val is
    select nro_cuenta,
           trunc(fecha) fecha,
           estado,
           tipo,
           tip_interes,
           tip_renovacion,
           tip_documento,
           sal_capital,
           sal_interes,
           sal_int_adelantado,
           dev_no_cobrado,
           tot_gar_computables,
           tot_prevision,
           cat_automatica,
           cotizacion,
           tot_val_capital,
           tot_val_interes,
           tot_val_int_ade,
           tot_val_devengado,
           tot_val_garantia,
           tot_val_prevision,
           dev_suspenso,
           tot_val_suspenso,
           cot_anterior,
           val_int_devengar,
           tot_val_int_devengar,
           tot_valuacion,
           usu_insercion,
           usu_modificacion,
           fec_insercion,
           fec_modificacion
      from it.pr_valuaciones@uenodesg v
     where exists (select 1 from pr_cta_prestamos p
                    where v.nro_cuenta = p.nro_cuenta)
       and not exists (select 1 from pr_valuaciones p
                        where v.nro_cuenta = p.nro_cuenta
                          and v.fecha = p.fecha);
     

  v_error varchar2(500);
  v_err   varchar2(500);
  v_ermsj varchar2(500);
  v_fecha date := sysdate;
  v_fec   date := pag_cal.fu_obt_fec_actual(1);
begin

  begin
    pre_ini_aplicacion;
    pae_cnf.G_COD_MODULO := '1';
  end;

  --Desabilitar los triggers
  sql_util.ejecute_dml('alter table pr_valuaciones disable all triggers',
                       v_err);
  if v_err is not null then
    raise_application_error(-20000, 'Al desabilitar triggers ' || v_err);
  end if;

  delete mi_logs 
   WHERE proceso in ('PR_VALUACIONES','PR_VALUACIONES_HIS');
  /*
  delete pr_valuaciones;
  delete pr_valuaciones_his;
  */
  for a in val loop
    begin
      insert into pr_valuaciones
        (nro_cuenta,
         fecha,
         estado,
         tipo,
         tip_interes,
         tip_renovacion,
         tip_documento,
         sal_capital,
         sal_interes,
         sal_int_adelantado,
         dev_no_cobrado,
         tot_gar_computables,
         tot_prevision,
         cat_automatica,
         cotizacion,
         tot_val_capital,
         tot_val_interes,
         tot_val_int_ade,
         tot_val_devengado,
         tot_val_garantia,
         tot_val_prevision,
         dev_suspenso,
         tot_val_suspenso,
         cot_anterior,
         val_int_devengar,
         tot_val_int_devengar,
         tot_valuacion,
         usu_insercion,
         usu_modificacion,
         fec_insercion,
         fec_modificacion)
      values
        (a.nro_cuenta,
         a.fecha,
         a.estado,
         a.tipo,
         a.tip_interes,
         a.tip_renovacion,
         a.tip_documento,
         a.sal_capital,
         a.sal_interes,
         a.sal_int_adelantado,
         a.dev_no_cobrado,
         a.tot_gar_computables,
         a.tot_prevision,
         a.cat_automatica,
         a.cotizacion,
         a.tot_val_capital,
         a.tot_val_interes,
         a.tot_val_int_ade,
         a.tot_val_devengado,
         a.tot_val_garantia,
         a.tot_val_prevision,
         a.dev_suspenso,
         a.tot_val_suspenso,
         a.cot_anterior,
         a.val_int_devengar,
         a.tot_val_int_devengar,
         a.tot_valuacion,
         a.usu_insercion,
         a.usu_modificacion,
         a.fec_insercion,
         a.fec_modificacion);
    exception
      when others then
        v_error := sqlcode;
        v_ermsj := sqlerrm;
        insert into mi_logs
          (nro_reg, nro_error, men_error, comentario, proceso, fec_proceso)
        values
          (1, v_error, v_ermsj, a.nro_cuenta, 'PR_VALUACIONES', v_fecha);
    end;
  end loop;

  

  --Habilitar los triggers
  sql_util.ejecute_dml('alter table pr_valuaciones enable all triggers',
                       v_err);
  if v_err is not null then
    raise_application_error(-20000, 'Al habilitar triggers ' || v_err);
  end if;
exception
  when others then
    v_error := sqlcode;
    v_ermsj := nvl(v_err, sqlerrm);
    v_fecha := sysdate;
    insert into mi_logs
      (nro_reg, nro_error, men_error, comentario, proceso, fec_proceso)
    values
      (1,
       v_error,
       v_ermsj,
       'verif_job_pr_valuaciones',
       'PR_VALUACIONES',
       v_fecha);
    commit;
end;
/

