CREATE OR REPLACE TRIGGER IT.TB_LC_TRANSFERENCIAS
  BEFORE INSERT OR DELETE OR UPDATE
     ON LC_TRANSFERENCIAS
    FOR EACH row
declare
v_bco_corresponsal ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('COD_BCO_SWI_CORRESPONSAL','','',:new.cod_moneda,'');--corresponsal/es
v_hab_gpi_hb  ge_par_dinamicos.val_parametro%type := nvl(fug_obt_pardinamico('HAB_GPII_HB',null,null,null,null),'N');

v_exi_banco number;
v_existe number; --RM: 12.09.2012 - bbvades-2015 -Bandera para indicar la existencia de la referencia general
v_cantidad number;
BEGIN

   begin
      select instr(','||v_bco_corresponsal||',' ,  ','||:new.cod_bco_corresponsal||',')
        into v_exi_banco
        from dual;
   exception
      when others then
         v_exi_banco := 0;
   end;

  if inserting then
    SELECT COUNT(*)
    INTO v_cantidad
    FROM lc_transferencias lt
    WHERE lt.fec_insercion BETWEEN (sysdate - 10 / 86400) AND sysdate
       AND lt.monto = :new.monto
       AND lt.fec_operacion = :new.fec_operacion
       AND lt.cod_per_solicitante = :new.cod_per_solicitante
       AND lt.nro_cta_referencia = :new.nro_cta_referencia
       AND lt.nro_cta_debito = :new.nro_cta_debito;
    
    IF v_cantidad = 0 then
     --si viene del swift, sólo por inserción por ahora
     if :new.msj_swift is not null then
        if :new.estado is null then
           -- FB: 05.11.2009 Se modifica el estado inicial a B-Bloqueada a pedido de COMEX
           --:new.estado := 'PE'; --pendiente, transf. recibidas
           :new.estado := 'B';
        end if;
     end if;
     --FB: 07.05.2010 Modificacion solicitada por HBengoa para limitar el bco corresponsal a utilizar para las transf. enviadas.
     --RM: 12.09.2012 - bbvades-2015 - Se agrega para que la condición también sea que el programa desde el que se ejecuta sea igual a LMTRANSF.
     if :new.cod_modalidad = 72 and pae_cnf.G_PROGRAMA = 'LMTRANSF' then
        if (:new.cod_moneda = 'EUR' and v_exi_banco = 0) then
            RAISE_APPLICATION_ERROR( -20000, 'Bco. Corresponsal no válido. '||'Para EUR corresponde el/los Banco/s '||v_bco_corresponsal);
        elsif (:new.cod_moneda = pag_gen.fu_obt_mon_fuerte and v_exi_banco = 0) then
            RAISE_APPLICATION_ERROR( -20000, 'Bco. Corresponsal no válido. '||'Para '||pag_gen.fu_obt_mon_fuerte||' corresponde el/los Banco/s '||v_bco_corresponsal);
        end if;
        -- RM: 12.09.2012 - bbvades-2015- Validar Tramos. Validar el monto de la transferencia.

        begin

          select count(1)
            into v_existe
            from ba_cod_referencias r
           where r.dominio = 'TRA_CORRESPONSAL_'||UPPER(:new.cod_moneda)
             and r.abreviatura = :new.cod_bco_corresponsal
            and :new.monto between FUG_CON_NUMERO(r.val_minimo)/*to_number(replace(r.val_minimo,',','.'))*/ and FUG_CON_NUMERO(r.val_maximo)/*to_number(replace(r.val_maximo,',','.'))*/;
        exception
          when others then
            RAISE_APPLICATION_ERROR( -20000,'Error al buscar Tramos. '||sqlerrm);
        end;
        if v_existe = 0 then
          RAISE_APPLICATION_ERROR( -20000,'Monto de la operación para el corresponsal '||:new.cod_bco_corresponsal||' debe estar dentro del rango.');
        end if;
     end if;

     if trim(upper(:NEW.USU_INSERCION))='HBANK' AND nvl(v_hab_gpi_hb,'N') ='S' THEN
         --GPII
        :new.gpi:='S'; --Solo GPII
     end if;
    ELSE
      RAISE_APPLICATION_ERROR( -20000, 'Operación similiar, intente de nuevo en unos minutos.');
    END IF;
  end if;
  --FB 05.11.2009 : Las transferencias recibidas ingresan en estado BLOQUEADO,
  --en este estado solo el rol COMEX podra modificar la transferencia
  if updating then
     if (:old.estado = 'B' or :new.estado = 'B') and
        fug_tie_rol_asociado(user,fug_obt_pardinamico('MOD_TRA_BLOQUEADAS',null,null,null,null)) = 'N' then
        RAISE_APPLICATION_ERROR( -20000, 'Usuario sin privilegio para modificar Transferencia.' );
     end if;
     --FB: 07.05.2010 Modificacion solicitada por HBengoa para limitar el bco corresponsal a utilizar para las transf. enviadas.
     --RM: 12.09.2012 - bbvades-2015- Se agrega para que la condición también sea que el programa desde el que se ejecuta sea igual a LMTRANSF.
     if :old.cod_bco_corresponsal <> :new.cod_bco_corresponsal and :old.cod_modalidad = 72 and pae_cnf.G_PROGRAMA = 'LMTRANSF' then
        if (:old.cod_moneda = 'EUR' and v_exi_banco = 0) then
           RAISE_APPLICATION_ERROR( -20000, 'Bco. Corresponsal no válido. '||'Para EUR corresponde el/los Banco/s '||v_bco_corresponsal);
        elsif (:old.cod_moneda = pag_gen.fu_obt_mon_fuerte and v_exi_banco = 0) then
           RAISE_APPLICATION_ERROR( -20000, 'Bco. Corresponsal no válido. '||'Para '||pag_gen.fu_obt_mon_fuerte||' corresponde el/los Banco/s '||v_bco_corresponsal);
        end if;
        -- RM: 12.09.2012 - bbvades-2015- Validar Tramos. Validar el monto de la transferencia.
        begin
          select count(1)
            into v_existe
            from ba_cod_referencias r
           where r.dominio = 'TRA_CORRESPONSAL_'||UPPER(:new.cod_moneda)
             and r.abreviatura = :new.cod_bco_corresponsal
             and :new.monto between FUG_CON_NUMERO(r.val_minimo)/*to_number(replace(r.val_minimo,',','.'))*/ and FUG_CON_NUMERO(r.val_maximo)/*to_number(replace(r.val_maximo,',','.'))*/;
        exception
          when others then
            RAISE_APPLICATION_ERROR( -20000,'Error al buscar Tramos. '||sqlerrm);
        end;
        if v_existe = 0 then
          RAISE_APPLICATION_ERROR( -20000,'Monto de la operación para el corresponsal '||:new.cod_bco_corresponsal||' debe estar dentro del rango.');
        end if;
     end if;

     -- CB. 16/10/2013. SPI 2441. En caso que ya haya generado movimiento al corresponal equivocado ( o por defecto) debe revertir ese movimiento e imputar al correcto.
     IF :old.cod_bco_corresponsal <> :new.cod_bco_corresponsal AND :old.cod_modalidad = 75 AND pae_cnf.G_PROGRAMA = 'LMTRANSF' THEN
        DECLARE
           v_new_nro_cuenta           ge_movimientos.nro_cuenta%type;
           v_cod_ofi_cta_corresponsal cc_cta_bancarias.cod_oficina%type;
           v_concepto                 varchar2(100);
           v_old_nro_cuenta           ge_movimientos.nro_cuenta%type;
           v_cod_ofi_mov              ge_movimientos.cod_oficina%type;
           v_concepto_mov             ge_movimientos.concepto%type;
           v_cod_rub_mov              ge_movimientos.cod_rubro%type;
        BEGIN
           select b.nro_cuenta, b.cod_oficina cod_ofi_cta_corresponsal,
                  substr('//'||:new.nro_ref_externa||'//'||:new.nom_beneficiario,1,100) concepto,
                  h.nro_cuenta, h.cod_oficina, h.concepto, h.cod_rubro
             into v_new_nro_cuenta, v_cod_ofi_cta_corresponsal, v_concepto, v_old_nro_cuenta,
                  v_cod_ofi_mov, v_concepto_mov, v_cod_rub_mov
             from cc_cta_bancarias b, cc_movimientos_his h
            where :new.cod_bco_corresponsal = b.cod_banco
              and :new.cod_modalidad = 75
              and b.cod_modalidad = 45
              and b.estado = 'N'
              and :new.cod_moneda = b.cod_moneda
              and :new.fec_valor between  (pag_cal.fu_obt_fec_actual(7) - 60) and pag_cal.fu_obt_fec_actual(7)
              and :new.fec_operacion >= (pag_cal.fu_obt_fec_actual(7) - 60)
              and :new.estado not in ('AN','DE')
              and h.cod_tra_padre = 1254
              and h.cod_transaccion = 1503
              and h.concepto  like '//'||:new.nro_ref_externa||'//%'
              and h.reversado ='N'
              and h.nro_documento = :new.NRO_REFERENCIA
              and h.fecha >= (pag_cal.fu_obt_fec_actual(7) - 60);

           DECLARE
              v_hora          ge_movimientos.hora%Type;
              v_fecha         ge_movimientos.fecha%Type;
              v_nro_secuencia ge_movimientos.nro_secuencia%Type := 0;
           BEGIN
              v_hora  := fug_ini_hora(SYSDATE,'HH24:MI:SS');
              v_fecha := pag_cal.fu_obt_fec_actual(7);

              pag_cta.pr_set_cod_rubro(v_cod_rub_mov,'C');
              pag_cta.pr_act_operacion(v_old_nro_cuenta,
                                       v_hora,
                                       'C',
                                       :new.cod_moneda,
                                       :new.monto,
                                       1254,
                                       602,
                                       :new.nro_referencia,
                                       null,
                                       v_cod_ofi_mov,
                                       7,
                                       75,
                                       null,
                                       null,
                                       v_concepto_mov,
                                       null,
                                       v_nro_secuencia,
                                       v_fecha,
                                       null,
                                       null,
                                       null);
              IF pag_cta.fu_obt_cod_error() <> 0 THEN
                 raise_application_error(-20790,'Reversión - Fondeo. '||pag_cta.fu_obt_msj_error());
              END IF;

              pag_cta.pr_set_cod_rubro(null, null);
              pag_cta.pr_act_operacion(v_new_nro_cuenta,
                                       v_hora,
                                       'D',
                                       :new.cod_moneda,
                                       :new.monto,
                                       1254,
                                       503,
                                       :new.nro_referencia,
                                       null,
                                       v_cod_ofi_cta_corresponsal,
                                       7,
                                       75,
                                       null,
                                       null,
                                       v_concepto,
                                       null,
                                       v_nro_secuencia,
                                       v_fecha,
                                       null,
                                       null,
                                       null);
              IF pag_cta.fu_obt_cod_error() <> 0 THEN
                 raise_application_error(-20791,'Débito - Fondeo. '||pag_cta.fu_obt_msj_error());
              END IF;

           END;
        EXCEPTION
           WHEN no_data_found THEN
              null; -- Si aun no se generó movimiento, no debe realizar
           WHEN others THEN
              RAISE_APPLICATION_ERROR( -20792,'Error al buscar Movimientos. '||sqlerrm);
        END;
     END IF;

  end if;
  if :new.estado <> :old.estado or inserting then
     :new.fec_cam_estado := pag_cal.FU_OBT_FEC_ACTUAL(7);
  end if;
  if :new.estado <> :old.estado then
     :new.est_anterior := :old.estado;
  end if;
  if :new.saldo = 0 and :new.cod_modalidad = 75 and :new.estado <> 'OK' then
      :new.est_anterior := :old.estado;
      :new.estado := 'OK';
      :new.fec_cam_estado := pag_cal.FU_OBT_FEC_ACTUAL(7);
  end if;
END;
/

