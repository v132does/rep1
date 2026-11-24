create or replace procedure it.PRA_CTA_INACTIVA is
   v_fec_actual     ge_calendarios.fec_actual%type;
   v_fec_proceso    ge_pag_sueldos.fec_proceso%type;
   v_val_parametro  ge_par_dinamicos.val_parametro%type;
   v_can_dia_inactivo number(3);
   v_can_cta_inactivo number(4);
   v_can_ent_inactivo number(3);
   v_programa       ge_log_errores.cod_programa%type :='PRA_CTA_INACTIVA';
   v_errores        ge_log_errores.det_error%type;
   v_cuenta         ah_cta_vistas.nro_cuenta%type;
   v_ente           ge_entes.cod_ente%type;
   ---CURSOR DE CUENTAS DE SALARIO
   cursor c is
     select c.nro_cuenta,c.cod_ente
     from ah_cta_vistas c,ge_entes e
     where c.cod_ente is not null
     and c.cod_ente=e.cod_ente
     and e.tipo='SU';
begin
   v_errores :='Inicio del proceso';
   v_cuenta := null;
   v_ente := null;
   for c_cuenta in c loop
     v_cuenta := c_cuenta.nro_cuenta;
     v_ente := c_cuenta.cod_ente;
    v_fec_actual := pag_cal.FU_OBT_FEC_ACTUAL(1);
  --OBTENEMOS LA ULTIMA FECHA DE MOVIMIENTO DE LA TABLA PAGOS DE SUELDOS
   begin
              select p.fec_ult_acreditacion into v_fec_proceso
              from ge_cta_entes p
              where p.nro_cuenta=c_cuenta.nro_cuenta
              and p.cod_ente=c_cuenta.cod_ente;
   exception
              when others then
              v_fec_proceso := trunc(sysdate);
   end;
   begin
              select gpd.val_parametro into v_val_parametro
              from ge_par_dinamicos gpd
              where gpd.parametro='CAN_DIA_CTA_INACTIVO';
   exception
              when others then
              v_val_parametro := '365';
   end;
       --COMPARAR LA FECHA DE ACREDITACION CON LA FECHA ACTUAL
       v_can_dia_inactivo := v_fec_actual - v_fec_proceso;
       if v_can_dia_inactivo > to_number(v_val_parametro) then
         update ge_cta_entes set cta_ent_estado='I'
         where nro_cuenta=c_cuenta.nro_cuenta
         and cod_ente=c_cuenta.cod_ente;
         --commit;
         --VERIFICAMOS SI UNA DE LAS CUENTAS ESTA ACTIVA
          begin
              select count(*) into v_can_cta_inactivo
              from ge_cta_entes
              where nro_cuenta=c_cuenta.nro_cuenta
              and cta_ent_estado='A';
          exception
              when others then
              v_can_cta_inactivo := 0;
          end;
              if v_can_cta_inactivo = 0 then
                 update ge_cta_dat_adicionales set val_parametro='I'
                 where nro_cuenta=c_cuenta.nro_cuenta
                 and parametro='PAG_CTA_AHO_EST';
                 if SQL%NOTFOUND then
                 insert into ge_cta_dat_adicionales(nro_cuenta,parametro,val_parametro) VALUES (c_cuenta.nro_cuenta,'PAG_CTA_AHO_EST','I');
                 end if;
                 --commit;
              end if;

      --VERIFICAMOS SI UNO DE LOS ENTES ESTA ACTIVA
              begin
                    select count(*) into v_can_ent_inactivo
                    from ge_cta_entes
                    where cod_ente=c_cuenta.cod_ente
                    and cta_ent_estado='A';
             exception
             when others then
                  v_can_ent_inactivo := 0;
             end;
             if v_can_ent_inactivo = 0 then
                update ge_par_entes set val_parametro='I'
                where cod_ente=c_cuenta.cod_ente
                and parametro='PAG_ENT_EST';
                if SQL%NOTFOUND then
                   insert into ge_par_entes(cod_ente,parametro,val_parametro) VALUES (c_cuenta.cod_ente,'PAG_ENT_EST','I');
                end if;
                --commit;
             end if;
       end if;
  end loop;
  exception
      when others then
      v_errores := substr(sqlerrm,4000);
      PRG_INS_LOG_PROGRAMAS(v_programa,'Error en el cierre:' || v_errores,null,v_cuenta ||'-'|| v_ente);
end;
/

