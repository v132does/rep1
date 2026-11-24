CREATE OR REPLACE TRIGGER IT.TB_GE_MOVIMIENTOS_NOC
 BEFORE DELETE OR INSERT OR UPDATE
  ON GE_MOVIMIENTOS_NOC
 FOR EACH ROW
DECLARE
  v_mto_sal_lim_cta_basica number(18,2);
  v_per_cta_basica varchar2(1);
  v_tipo ge_transacciones.tipo%type;
  v_tot_cre_mes ge_movimientos.monto%type;
  v_exc_transaccion varchar2(1) := 'N';
  v_pri_dia_mes ge_calendarios.fec_actual%type;
  v_fec_actual ge_calendarios.fec_actual%type := pag_cal.FU_OBT_FEC_ACTUAL(3);
  v_fec_movimiento ge_calendarios.fec_actual%type;
BEGIN
  --Control por Proyecto Cuenta Basica--
  if inserting then
   if nvl(fug_obt_pardinamico('ACT_VAL_CTA_BASICA'),'N') = 'S' then --ACTIVA VALIDACIONES DE CUENTA BASICA
    if nvl(PAE_CNF.G_PROGRAMA,'x') != 'GPPROFIN' and :new.cod_modulo = 3 and :new.cod_modalidad = 31 then
       v_per_cta_basica := fua_es_cta_basica(:new.nro_cuenta);
       if nvl(v_per_cta_basica, 'N') = 'S' then
          v_fec_movimiento := pag_cal.FU_OBT_FEC_HABIL(v_fec_actual+1, 1, 1);

          -- EM EL DIARIO CAMBIA LA FECHA DEL CALENDARIO
          v_pri_dia_mes := (trunc(pag_cal.FU_OBT_FEC_HABIL(v_fec_movimiento, 1, 1), 'mm'));

          begin
            select 'S'
              into v_exc_transaccion
              from ge_gru_transacciones_det t
             where cod_gru_transaccion = 91
               and cod_modulo = :new.cod_mod_padre
               and cod_modalidad = :new.cod_mad_padre
               and cod_transaccion = :new.cod_tra_padre;
          exception
            when others then
              v_exc_transaccion := 'N';
          end;
          if nvl(v_exc_transaccion, 'N') = 'N' then
              begin
                select 'S'
                  into v_exc_transaccion
                  from ge_gru_transacciones_det t
                 where cod_gru_transaccion = 91
                   and cod_modulo = :new.cod_modulo
                   and cod_modalidad = :new.cod_modalidad
                   and cod_transaccion = :new.cod_transaccion;
              exception
                when others then
                  v_exc_transaccion := 'N';
              end;
            end if;

          if nvl(v_exc_transaccion, 'N') = 'N' then
             --Verificar si es un credito--
             begin
               select b.tipo
                 into v_tipo
                 from ge_transacciones b
                where b.cod_modulo = :new.cod_modulo
                  and b.cod_modalidad = :new.cod_modalidad
                  and b.cod_transaccion = :new.cod_transaccion;
             exception
               when others then
                 v_tipo := 'X';
             end;
             if nvl(v_tipo, 'X') = 'C' then
               begin
                 select sum(monto)
                   into v_tot_cre_mes
                   from ge_mov_cre_cta_bas x
                  where x.nro_cuenta = :new.nro_cuenta
                    and x.fecha >=  v_pri_dia_mes
                    and x.fecha <= v_fec_movimiento;
               exception
                 when others then
                   v_tot_cre_mes := 0;
               end;

                --Buscar el limite de la cuenta basica--
                v_mto_sal_lim_cta_basica := NVL(fug_obt_pardinamico('MTO_MAX_AHO_CTA_BASICA',NULL,NULL,:NEW.COD_MONEDA),0);
                if nvl(v_tot_cre_mes,0) + nvl(:new.monto,0) > nvl(v_mto_sal_lim_cta_basica,0) then
                   if nvl(fug_obt_pardinamico('ACT_LOG_CTA_BASICA'),'N') = 'S' then
                       prg_ins_log_errores('TB_GE_MOVIMIENTOS_NOC','La Cuenta Basica no puede superar Limite de Crédito establecido. '||'Trans Cred. '||to_char(:new.cod_transaccion),
                                           'COD_TRA_PADRE', to_char(:new.cod_mod_padre)||'-'||to_char(:new.cod_mad_padre)||'-'||to_char(:new.cod_tra_padre),
                                           'NRO_CUENTA', :new.nro_cuenta,
                                           'MONTO', to_char(:new.monto));
                   end if;

                   raise_application_error(-20008, 'La Cuenta Basica no puede superar Limite de Crédito establecido');
                else
                  begin
                    insert into ge_mov_cre_cta_bas (fecha,hora,cod_usuario,nro_secuencia,fec_valor,cod_modulo,cod_modalidad,
                                                    nro_cuenta,cod_tra_padre,cod_moneda,monto,nro_documento)
                         values (:new.fecha, :new.hora, :new.cod_usuario, :new.nro_secuencia, :new.fec_valor, :new.cod_modulo, :new.cod_modalidad,
                                 :new.nro_cuenta, :new.cod_tra_padre, :new.cod_moneda, :new.monto, :new.nro_documento);
                  exception
                    when others then
                     raise_application_error(-20008, 'No se puede ingresar el credito de Cuenta Básica. '||sqlerrm);
                  end;
                end if;
             end if;
          end if;
       end if;
     end if;
    end if;
  end if;
EXCEPTION
  WHEN OTHERS THEN
   raise_application_error(-20003,'TB_GE_MOVIMIENTOS_NOC -'||sqlerrm);
END TB_GE_MOVIMIENTOS_NOC;
/

