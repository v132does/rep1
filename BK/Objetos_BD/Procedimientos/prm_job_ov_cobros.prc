create or replace procedure it.prm_job_ov_cobros is

  cursor co is
    select replace(translate(nro_cuenta,
                             'ABCDEFGHIJLAMNOPQRSTUVWYXXZabcdefghijklmnopqrstuvwyz*Ç}°-,/-.\+|',
                             ' '),
                   ' ',
                   '') nro_cuenta,
           fecha,
           hora,
           estado,
           sal_total,
           fec_ult_pago,
           dia_mora,
           mto_total,
           mto_int_moratorio,
           mto_int_punitorio,
           mto_cargo,
           mto_cargo_iva,
           mto_impuesto,
           nro_documento,
           mto_int_mor_cal,
           mto_int_pun_cal,
           mto_cargo_cal,
           mto_car_iva_cal,
           mto_impuesto_cal,
           mto_car_des,
           mto_int_mor_des,
           mto_int_pun_des,
           usu_insercion,
           fec_insercion,
           usu_modificacion,
           fec_modificacion
      from it.ov_cobros@uenodesg a
      where not exists (select * from ov_cobros b
                        where a.nro_cuenta = b.nro_cuenta
                        and   a.fecha = b.fecha
                        and   a.hora  = b.hora);

  v_error   varchar2(500);
  v_err     varchar2(500);
  v_ermsj   varchar2(500);
  v_fecha   date := sysdate;
  v_fec     date := pag_cal.fu_obt_fec_actual(1);
  v_cod_mod NUMBER;

begin

  begin
    pre_ini_aplicacion;
    pae_cnf.G_COD_MODULO := '1';
  end;

  --Desabilitar los triggers
  sql_util.ejecute_dml('alter table it.ov_cobros disable all triggers',
                       v_err);

  delete mi_logs where proceso = 'OV_COBROS';

  sql_util.ejecute_dml('alter table ge_cuentas disable all triggers',
                       v_err);
  sql_util.ejecute_dml('alter table ge_cta_clientes disable all triggers',
                       v_err);
  if v_err is not null then
    raise_application_error(-20000, 'Al desabilitar triggers ' || v_err);
  end if;
  --Habilitar trigger
  sql_util.ejecute_dml('alter trigger ta_ov_cobros enable', v_err);

  for a in co loop
    begin
      insert into it.ov_cobros
        (  nro_cuenta,
           fecha,
           hora,
           estado,
           sal_total,
           fec_ult_pago,
           dia_mora,
           mto_total,
           mto_int_moratorio,
           mto_int_punitorio,
           mto_cargo,
           mto_cargo_iva,
           mto_impuesto,
           nro_documento,
           mto_int_mor_cal,
           mto_int_pun_cal,
           mto_cargo_cal,
           mto_car_iva_cal,
           mto_impuesto_cal,
           usu_insercion,
           fec_insercion,
           usu_modificacion,
           fec_modificacion,
           mto_car_des,
           mto_int_mor_des,
           mto_int_pun_des)
      values
        (  a.nro_cuenta,
           a.fecha,
           a.hora,
           a.estado,
           a.sal_total,
           a.fec_ult_pago,
           a.dia_mora,
           a.mto_total,
           a.mto_int_moratorio,
           a.mto_int_punitorio,
           a.mto_cargo,
           a.mto_cargo_iva,
           a.mto_impuesto,
           a.nro_documento,
           a.mto_int_mor_cal,
           a.mto_int_pun_cal,
           a.mto_cargo_cal,
           a.mto_car_iva_cal,
           a.mto_impuesto_cal,
           a.usu_insercion,
           a.fec_insercion,
           a.usu_modificacion,
           a.fec_modificacion,
           a.mto_car_des,
           a.mto_int_mor_des,
           a.mto_int_pun_des);

    exception
      when others then
        v_error := sqlcode;
        v_ermsj := sqlerrm;
        insert into mi_logs
          (nro_reg, nro_error, men_error, comentario, proceso, fec_proceso)
        values
          (1, v_error, v_ermsj, a.nro_cuenta, 'OV_COBROS', v_fecha);
    end;

  
  end loop;

  --Habilitar los triggers
  sql_util.ejecute_dml('alter table it.ov_cobros enable all triggers',
                       v_err);
  sql_util.ejecute_dml('alter table ge_cuentas enable all triggers', v_err);
  sql_util.ejecute_dml('alter table ge_cta_clientes enable all triggers',
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
       'verif_job_ov_cobros',
       'OV_COBROS',
       v_fecha);
    commit;
end prm_job_ov_cobros;
/

