create or replace trigger it.ta_ge_sal_inv_vta_cartera_his
 after delete or insert or update
 on ge_sal_inv_vta_cartera_his
 for each row
declare
  v_lugar    varchar2(500);
  v_cod_moneda        pr_cta_prestamos.cod_moneda%type;
  v_fec_inicio        pr_cta_prestamos.fec_inicio%type;
  v_fec_vencimiento   pr_cta_prestamos.fec_vencimiento%type;
  v_mto_capital       pr_cta_prestamos.mto_capital%type;
  v_can_cuotas        pr_cta_prestamos.can_cuotas%type;
  v_cod_sec_credito   pr_cta_prestamos.cod_sec_credito%type;
  v_val_tasa          pr_cta_prestamos.val_tasa%type;
  v_tipo              pr_cta_prestamos.tipo%type;

begin
       if inserting and :new.nro_cuenta is not null and :new.cod_modulo = 6 then
           v_lugar := 'Insertando Nuevo Registro';

            begin
                 select p.cod_moneda,p.fec_inicio,p.fec_vencimiento,p.mto_capital,
                        p.can_cuotas,p.cod_sec_credito,p.val_tasa,p.tipo
                   into v_cod_moneda,v_fec_inicio,v_fec_vencimiento,v_mto_capital,
                        v_can_cuotas,v_cod_sec_credito,v_val_tasa,v_tipo
                   from pr_cta_prestamos p
                  where p.nro_cuenta    = :new.nro_cuenta
                    and p.cod_modulo    = :new.cod_modulo
                    and p.cod_modalidad = :new.cod_modalidad
                    and p.cod_oficina   = :new.cod_oficina;
            exception
              when others then
                v_cod_moneda := null;
                v_fec_inicio := null;
                v_fec_vencimiento := null;
                v_mto_capital := null;
                v_can_cuotas := null;
                v_cod_sec_credito := null;
                v_val_tasa := null;
            end;

              insert into pr_vta_carteras v
                (v.cod_ente,
                 v.fec_ope_ente,
                 v.nro_cuenta,
                 v.cod_oficina,
                 v.cod_moneda,
                 v.cod_modulo,
                 v.cod_modalidad,
                 v.fec_inicio,
                 v.fec_vencimiento,
                 v.mto_capital,
                 v.can_cuotas,
                 v.cod_sec_credito,
                 v.val_tasa,
                 v.cod_persona,
                 v.tipo,
                 v.estado,
                 v.est_batch,
                 v.cat_cliente,
                 v.dia_atraso,
                 v.tot_riesgo,
                 v.ope_recaptada,
                 v.usu_insercion,
                 v.fec_insercion,
                 v.usu_modificacion,
                 v.fec_modificacion,
                 v.sal_capital,
                 v.dev_no_cobrado)
              Values
                (:new.cod_ente,
                 :new.fec_venta,
                 :new.nro_cuenta,
                 :new.cod_oficina,
                 v_cod_moneda,
                 :new.cod_modulo,
                 :new.cod_modalidad,
                 v_fec_inicio,
                 v_fec_vencimiento,
                 v_mto_capital,
                 v_can_cuotas,
                 v_cod_sec_credito,
                 v_val_tasa,
                 :new.cod_persona,
                 v_tipo,
                 :new.estado,
                 :new.estado,
                 :new.cat_cliente,
                 :new.dia_atrasos,
                 :new.tot_riesgo,
                 :new.ope_recaptados,
                 :new.usu_venta,
                 :new.fecha,
                 :new.usu_venta,
                 :new.fec_venta,
                 :new.mto_deu_mon_cuenta,
                 :new.mto_deu_mon_cuenta);
        
       elsif    updating and (:new.ope_recaptados) <> 'N' then
              v_lugar := 'Actualizando Registro';

               update pr_vta_carteras v
                  set v.ope_recaptada = :new.ope_recaptados
                where v.nro_cuenta = :old.nro_cuenta;

       elsif deleting  then
              v_lugar := 'Borrando Registro';

              delete pr_vta_carteras v
               where v.nro_cuenta = :old.nro_cuenta
                 and v.fec_ope_ente = :old.fec_venta;
       end if;
exception
    when others then
         prg_ins_log_errores('TA_GE_SAL_INV_VTA_CARTERA_HIS',v_lugar||' : '||sqlerrm);
end;
/
