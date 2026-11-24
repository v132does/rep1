CREATE OR REPLACE TRIGGER IT.TB_GE_MOVIMIENTOS
 BEFORE DELETE OR INSERT OR UPDATE
  ON "IT"."GE_MOVIMIENTOS"
 FOR EACH ROW
DECLARE
v_tie_autorizacion number (5):= 0;
v_tip_mov_rubro varchar2(1);
v_cod_rubro varchar2(20);
v_batch varchar2(1);
v_cod_tip_asiento number(16);
v_mto_sal_lim_cta_basica number(18,2);
v_per_cta_basica varchar2(1);
v_tipo ge_transacciones.tipo%type;
v_tot_cre_mes ge_movimientos.monto%type;
v_exc_transaccion varchar2(1) := 'N';
BEGIN
  if inserting then
      -- OMM 12/11/2010 Para validar que se carge correctamente la transferencia para DNA (Sofia)
      if :new.cod_tra_padre = 309 and :new.nro_cuenta = '1101700874' and :new.reversado = 'N' then
           if (nvl(instr(trim(:new.concepto), '1101700052'), 0) = 0) then
             if nvl(fue_val_es_numerico(replace(trim(:new.concepto),'-','')),'N')='N' or
                nvl(INSTR(trim(:new.concepto), '-'),0) <> 4 then
                   raise_application_error(-20000,'Formato de Concepto Incorrecto para la transferencia. Formato debe ser: 999-9999999');
             end if;
           end if ;
      end if ;
      if :new.cod_tra_padre = 100 and :new.reversado <> 'S' then -- Para controlar Autorizacion por Cambios de TASA
         SELECT COUNT(*) into v_tie_autorizacion
           FROM GE_MOVIMIENTOS
          WHERE NRO_CUENTA = :new.nro_cuenta
            and ESTADO = 'X' -- pendiente de autorizar
            and REVERSADO = 'N';
         IF v_tie_autorizacion > 0 THEN
             raise_application_error(-20000,'Esta cuenta tiene Autorizaci?n pendiente. Debe ser previamente autorizada y retomada. '|| :new.nro_Cuenta);
         END IF;
      end if;
      -- cambiar la contabilizacion de cuentas bancarias si tiene rubro asociado
      if :new.cod_modulo = 4 and :new.cod_modalidad <> 41 and
         :new.cod_transaccion is not null and :new.monto <> 0 and :new.nro_cuenta is not null then
         begin
           if :new.cod_transaccion not in (504,9731) THEN
            select b.tipo, a.cod_rubro, b.batch, nvl(b.cod_tip_asiento,0)  + nvl(b.cod_tip_asiento2,0)
              into v_tip_mov_rubro, v_cod_rubro, v_batch, v_cod_tip_asiento
              from ge_transacciones b, cc_cta_bancarias a
             where a.nro_cuenta = :new.nro_cuenta
               and b.cod_modulo = :new.cod_modulo
               and b.cod_modalidad = :new.cod_modalidad
               and b.cod_transaccion = :new.cod_transaccion;
            end if;
        exception
            when others then
               null;
        end;
        -- Solo para la fase 2
        --if :new.cod_rubro is null and :new.cod_modalidad <> 43 /*and (v_batch = 'O' or v_cod_tip_asiento = 0) */then
        if :new.cod_rubro is null and v_cod_rubro is not null then
          :new.cod_rubro := v_cod_rubro;
          :new.tip_mov_rubro := v_tip_mov_rubro;
        end if;
      end if;
  end if;
  if (inserting or updating) and
     nvl(PAE_CNF.G_PROGRAMA,'x') != 'GPPROFIN' then
     --JG/06-2011 Se controla que los importes ingresados, tengan aplicados los decimales correctos.
     if :new.monto <> round(:new.monto,fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',null,null,:new.cod_moneda,null)) then
        --Se controla el valor MONTO sin importar la moneda.
        raise_application_error(-20001,'Importe en Moneda EXTRANJERA posee redondeo erroneo de acuerdo a la moneda del movimiento '
                                       ||' fecha '||to_char(:new.fecha)
                                       ||' hora '||:new.hora
                                       ||' usuario '||:new.cod_usuario
                                       ||' secuencia '||to_char(:new.nro_secuencia)
                                       ||' moneda '||:new.cod_moneda
                                       ||' trhijo '||to_char(:new.cod_transaccion)
                                       ||' importe '||to_char(:new.monto));
     end if;
     if :new.cod_moneda <> pag_gen.FU_OBT_MON_LOCAL and
        :new.mto_equ_local <> round(:new.mto_equ_local,fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',null,null,pag_gen.FU_OBT_MON_LOCAL,null)) then
        --Se controla el valor MTO_EQU_LOCAL cuando es moneda EXTRANJERA.
        raise_application_error(-20002,'Importe en Moneda LOCAL posee redondeo erroneo '
                                       ||' fecha '||to_char(:new.fecha)
                                       ||' hora '||:new.hora
                                       ||' usuario '||:new.cod_usuario
                                       ||' secuencia '||to_char(:new.nro_secuencia)
                                       ||' moneda '||:new.cod_moneda
                                       ||' trhijo '||to_char(:new.cod_transaccion)
                                       ||' importe '||to_char(:new.monto));
     end if;
     if nvl(:new.monto,0) = 0 and nvl(:new.mto_equ_local,0) = 0 and nvl(fug_obt_tip_mov_contable(:new.cod_modulo, :new.cod_modalidad, :new.cod_transaccion),'N') not in ('N','E')  then
        --AP 2984 VV/18-05-2012 Se controla que el monto del movimiento no sea Cero cuando el movimiento genera asientos contables.
        raise_application_error(-20002,'Monto Incorrecto para el tipo de movimiento '
                                       ||' fecha '||to_char(:new.fecha)
                                       ||' hora '||:new.hora
                                       ||' usuario '||:new.cod_usuario
                                       ||' secuencia '||to_char(:new.nro_secuencia)
                                       ||' moneda '||:new.cod_moneda
                                       ||' trhijo '||to_char(:new.cod_transaccion)
                                       ||' monto '||to_char(:new.monto));
     end if;
  end if;

  --Control por Proyecto Cuenta Basica--
  if inserting then
    if nvl(fug_obt_pardinamico('ACT_VAL_CTA_BASICA'),'N') = 'S' then --ACTIVA VALIDACIONES DE CUENTA BASICA
      if nvl(PAE_CNF.G_PROGRAMA,'x') != 'GPPROFIN' and :new.cod_modulo = 3 and :new.cod_modalidad = 31 then
         v_per_cta_basica := fua_es_cta_basica(:new.nro_cuenta);
         if v_per_cta_basica = 'S' then
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
                  --Buscar el saldo de la cuenta--
                  declare
                    v_pri_dia_mes ge_movimientos.fecha%type;
                  begin
                    v_pri_dia_mes := (trunc(pag_cal.FU_OBT_FEC_HABIL(:new.fecha, 1, 1), 'mm'));
                    select sum(monto)
                      into v_tot_cre_mes
                      from ge_mov_cre_cta_bas
                     where fecha between v_pri_dia_mes and :new.fecha
                       and nro_cuenta = :new.nro_cuenta;
                   exception
                     when others then
                       v_tot_cre_mes := 0;
                   end;

                  --Buscar el limite de la cuenta basica--
                  v_mto_sal_lim_cta_basica := NVL(fug_obt_pardinamico('MTO_MAX_AHO_CTA_BASICA',NULL,NULL,:NEW.COD_MONEDA),0);
                  if ( nvl(v_tot_cre_mes,0) + nvl(:new.monto,0)) > nvl(v_mto_sal_lim_cta_basica,0) then
                     prg_ins_log_errores('TB_GE_MOVIMIENTOS','La Cuenta Basica no puede superar Limite de Crédito establecido. '||'Trans Cred. '||to_char(:new.cod_transaccion),
                                         'COD_TRA_PADRE', to_char(:new.cod_mod_padre)||'-'||to_char(:new.cod_mad_padre)||'-'||to_char(:new.cod_tra_padre),
                                         'NRO_CUENTA', :new.nro_cuenta,
                                         'MONTO', to_char(:new.monto));

                     raise_application_error(-20008, 'La Cuenta Basica no puede superar Limite de Credito establecido');
                  else
                    begin
                      insert into ge_mov_cre_cta_bas (fecha,hora,cod_usuario,nro_secuencia,fec_valor,cod_modulo,cod_modalidad,
                                                      nro_cuenta,cod_tra_padre,cod_moneda,monto,nro_documento)
                           values (:new.fecha, :new.hora, :new.cod_usuario, :new.nro_secuencia, :new.fec_valor, :new.cod_modulo, :new.cod_modalidad,
                                   :new.nro_cuenta, :new.cod_tra_padre, :new.cod_moneda, :new.monto, :new.nro_documento);
                    exception
                      when others then
                       raise_application_error(-20008, 'No se puede ingresar el credito de Cuenta Basica. '||sqlerrm);
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
   raise_application_error(-20003,'TB_GE_MOVIMIENTOS -'||sqlerrm);
END TB_GE_MOVIMIENTOS;
/

