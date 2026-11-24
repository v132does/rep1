create or replace procedure it.prm_job_pr_devengados is

  cursor dev is
    select nro_cuenta,
           fec_inicio,
           val_tasa,
           mto_dev_anterior,
           mto_dev_actual,
           capital,
           nro_cuota,
           tipo,
           fecha,
           fec_ult_devengado,
           cod_moneda,
           estado,
           categoria,
           can_dia_interes,
           can_dia_anterior,
           mto_ajuste,
           mto_dev_acumulado,
           usu_insercion,
           usu_modificacion,
           fec_insercion,
           fec_modificacion
      from it.pr_devengados@uenodesg d
     where exists (select 1
              from pr_cta_prestamos x
             where d.nro_cuenta = x.nro_cuenta)
       and not exists
     (select 1 from pr_devengados p 
     where d.nro_cuenta = p.nro_cuenta
     and   d.tipo       = p.tipo
     and   d.nro_cuota  = p.nro_cuota
     and   d.cod_moneda = p.cod_moneda
     and   d.estado     = p.estado
     and   d.categoria  = p.categoria
     and   d.capital    = p.capital
     and   d.val_tasa   = p.val_tasa);

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
  sql_util.ejecute_dml('alter table pr_devengados disable all triggers',
                       v_err);
  if v_err is not null then
    raise_application_error(-20000, 'Al desabilitar triggers ' || v_err);
  end if;

  delete mi_logs where proceso = 'PR_DEVENGADOS';
  --delete pr_devengados;

  for a in dev loop
  
    begin
      insert into pr_devengados
        (nro_cuenta,
         fec_inicio,
         val_tasa,
         mto_dev_anterior,
         mto_dev_actual,
         capital,
         nro_cuota,
         tipo,
         fecha,
         fec_ult_devengado,
         cod_moneda,
         estado,
         categoria,
         can_dia_interes,
         can_dia_anterior,
         mto_ajuste,
         mto_dev_acumulado,
         usu_insercion,
         usu_modificacion,
         fec_insercion,
         fec_modificacion)
      values
        (a.nro_cuenta,
         a.fec_inicio,
         a.val_tasa,
         a.mto_dev_anterior,
         a.mto_dev_actual,
         a.capital,
         a.nro_cuota,
         decode(a.tipo, 'C', 'N', a.tipo),
         a.fecha,
         a.fec_ult_devengado,
         a.cod_moneda,
         a.estado,
         a.categoria,
         a.can_dia_interes,
         a.can_dia_anterior,
         a.mto_ajuste,
         a.mto_dev_acumulado,
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
          (1, v_error, v_ermsj, a.nro_cuenta, 'PR_DEVENGADOS', v_fecha);
    end;
  end loop;

  --Habilitar los triggers
  sql_util.ejecute_dml('alter table pr_devengados enable all triggers',
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
       'verif_job_pr_devengados',
       'PR_DEVENGADOS',
       v_fecha);
    commit;
end;
/

