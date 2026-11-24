create or replace PROCEDURE    it.prp_cob_pre_nocturnos IS
   v_fec_actual       ge_calendarios.fec_actual%type := pag_cal.FU_OBT_FEC_ACTUAL(6);
   v_nro_secuencia    ge_movimientos.nro_secuencia%type := 0;
   v_cod_rubro        ge_movimientos.cod_rubro%type;
   v_tip_pago         bw_pag_servicios.tip_pago%type;
   v_banco            bw_pag_servicios.cod_banco%type;
   v_cod_bco_central  ge_bancos.cod_bco_central%type;
   v_cod_banco        ge_bancos.cod_banco%type;
   v_cod_retorno      varchar2(3) := '000';
   v_cod_tra_padre    ge_movimientos.cod_tra_padre%type := 360;
   v_nro_cheque       ge_movimientos.nro_documento2%type;
   r_gmovi            ge_movimientos%ROWTYPE;
   r_ctapre           pr_cta_prestamos%rowtype;
   v_concepto         VARCHAR2(50);
   v_hora             varchar2(10);
   v_fecha            ge_calendarios.fec_actual%type := pag_cal.FU_OBT_FEC_ACTUAL(6);

   v_cta_bancaria     ge_movimientos.nro_cuenta%TYPE;
   v_red_pago         bw_pag_servicios.red_pago%type;
   v_nro_documento    ge_movimientos.nro_documento%type;
   v_hor_cobro        ge_movimientos.hora%TYPE;
   v_lugar            varchar2(200);
   v_error            varchar2(200);
   
   -- Variables nuevas para la alineacion del debito en GE_MOVIMIENTOS
   v_usu_pap_pre      ge_movimientos.cod_usuario%TYPE := NULL;


   --
   CURSOR C1 IS SELECT a.nro_cuenta, a.nro_cuota_desde, a.nro_cuota_hasta,
                       a.fecha, a.hora, a.nro_secuencia,
                       a.estado, a.mto_cobrado, a.cod_ofi_origen,
                       a.cod_mod_padre, a.cod_mad_padre, a.cod_tra_padre,
                       a.usu_insercion, b.cod_moneda,
                       a.rowid registro, a.cod_canal
                  FROM PR_COBROS_NOC a, PR_CTA_PRESTAMOS b
                 WHERE a.nro_cuenta = b.nro_cuenta
                   AND a.FECHA <= v_fec_actual
                   AND a.ESTADO = 'I'
                   AND a.MTO_COBRADO > 0
                 ORDER BY a.fecha, a.hora, a.usu_insercion;

   --cursor para las reversiones nocturnas
   CURSOR C2 IS SELECT nro_cuenta, nro_cuota_desde, nro_cuota_hasta,
                       fecha, hora, nro_secuencia,
                       estado, mto_cobrado, cod_ofi_origen,
                       cod_mod_padre, cod_mad_padre, cod_tra_padre,usu_insercion,
                       rowid registro
                  FROM PR_COBROS_NOC
                 WHERE FECHA <= v_fec_actual
                   AND ESTADO = 'I'
                   AND MTO_COBRADO < 0;

  function fu_obt_hor_disponible(p_fecha in date,
                                  p_hora in varchar2,
                                  p_nro_cuenta in varchar2,
                                  p_nro_cuota_desde in varchar2) 
   return varchar2 is
     v_existe varchar2(1);
     v_hora   varchar2(8) := p_hora;
   begin
     loop
      begin
        select 'S'
          into v_existe
          from pr_cobros_noc
         where fecha = p_fecha
           and hora = v_hora
           and nro_cuenta = p_nro_cuenta
           and nro_cuota_desde = p_nro_cuota_desde
           and rownum <= 1;
      exception
        when no_data_found then
          v_existe := 'N';
      end;
      exit when v_existe = 'N';
      v_hora := fug_obt_hor_disponible(p_fecha,v_hora,user,'N');
    end loop;
    return v_hora;
   end;

  FUNCTION lf_obt_cta_bancaria(p_red_pago varchar2, p_cod_moneda varchar2) return varchar2 is
    v_entidad          ba_cod_referencias.significado%TYPE := '';
    v_nom_parametro    ba_cod_referencias.significado%TYPE := '';
    v_bancaria     ge_movimientos.nro_cuenta%TYPE;

    BEGIN
        v_entidad := FUE_OBT_DES_REFERENCIA('PRE_COM_TRA_PAGSER',p_red_pago);
        If v_entidad = 'PRONET' then
          v_nom_parametro := 'COBRO';
        else
          v_nom_parametro := v_entidad;
        End if;

        v_bancaria := fug_obt_pardinamico('PRE_CTA_BAN_'||v_nom_parametro, NULL, NULL, p_cod_moneda);
        return v_bancaria;
    END;

BEGIN

   --- Marca los pagados anteriormente. No se aplica para las reversiones, por eso se modifica condicion
   UPDATE PR_COBROS_NOC CO
      SET ESTADO = 'A',
          FEC_PROCESO = v_fec_actual
    WHERE ESTADO = 'I'
      AND TRUNC(FECHA) <= v_fec_actual
      AND nvl(CO.MTO_COBRADO,0) > 0
      AND EXISTS (SELECT '1'
                    FROM PR_CUOTAS CU
                   WHERE CU.NRO_CUENTA = CO.NRO_CUENTA
                     AND CU.NRO_CUOTA between co.nro_cuota_desde and co.nro_cuota_hasta
                     AND CU.ESTADO = 'N');
   ---
   FOR R1 IN C1 LOOP
      
      savepoint v_sav_point;
     
       v_hor_cobro := fug_ini_hora(SYSDATE);
       v_hor_cobro := fu_obt_hor_disponible(r1.fecha, v_hor_cobro, r1.nro_cuenta, r1.nro_cuota_desde);

          IF v_nro_secuencia + 15 > 999 THEN
             v_nro_secuencia := 0;
             v_hor_cobro := fug_ini_hora(SYSDATE);
             v_hor_cobro := fu_obt_hor_disponible(r1.fecha, v_hor_cobro, r1.nro_cuenta, r1.nro_cuota_desde);
          END IF;

     if instr(fug_obt_pardinamico('COD_USU_PAG_SER'),R1.usu_insercion)>0 and nvl(r1.cod_canal,'000') != '999' then 
          pap_pre.pr_obt_dat_prestamo(r1.nro_cuenta, r_ctapre); 
          --obtiene el tipo de pago
          begin
            select s.tip_pago,s.cod_banco,s.nro_cheque, s.red_pago, s.nro_recibo, s.cod_rubro
              into v_tip_pago,v_cod_banco,v_nro_cheque, v_red_pago, v_nro_documento, v_cod_rubro
              from bw_pag_servicios s
             where s.nro_cuenta = r1.nro_cuenta
               and s.fecha = r1.fecha
               and s.hora = r1.hora;
          exception
            when no_data_found then
               raise_application_error(-20000,'Datos del pago de servicio no encontrado para la cuenta '||r1.nro_cuenta);
            when others then
               raise_application_error(-20001,'Error al buscar los datos del pago de servicio para la cuenta  '||r1.nro_cuenta||' '||sqlerrm);
          end;

          --aumentar la secuencia
          IF v_nro_secuencia + 15 > 999 THEN
             v_nro_secuencia := 0;
             v_hor_cobro := fug_ini_hora(SYSDATE);
             v_hor_cobro := fu_obt_hor_disponible(r1.fecha, v_hor_cobro, r1.nro_cuenta, r1.nro_cuota_desde);
          END IF;
          
          --obtencion de cta bancaria
          v_cta_bancaria := lf_obt_cta_bancaria(v_red_pago, r1.cod_moneda);

          v_lugar := 'al insertar movimientos en cta. nro '|| r1.nro_cuenta;
           IF v_cod_rubro is not null then
                 -- Movimiento contra rubro contable --
                 v_nro_secuencia         := v_nro_secuencia + 1;
                 r_gmovi.cod_usuario     := r1.usu_insercion;
                 r_gmovi.hora            := v_hor_cobro;
                 r_gmovi.fecha           := v_fec_actual;
                 r_gmovi.nro_secuencia   := v_nro_secuencia;
                 r_gmovi.cod_modulo      := r_ctapre.cod_modulo;
                 r_gmovi.cod_modalidad   := r_ctapre.cod_modalidad;
                 r_gmovi.cod_oficina     := r1.cod_ofi_origen;
                 r_gmovi.cod_moneda      := r_ctapre.cod_moneda;
                 r_gmovi.fec_valor       := r1.fecha;
                 r_gmovi.cod_tra_padre   := v_cod_tra_padre;
                 r_gmovi.cod_mod_padre   := r_ctapre.cod_modulo;
                 r_gmovi.cod_mad_padre   := r_ctapre.cod_modalidad;
                 r_gmovi.cod_transaccion := 842;
                 r_gmovi.monto           := r1.mto_cobrado;
                 r_gmovi.nro_documento3  := r1.nro_cuota_desde;
                 r_gmovi.cod_ofi_origen  := r1.cod_ofi_origen;
                 r_gmovi.emi_aviso       := 'N';
                 r_gmovi.concepto        := 'Cobro de cuenta '||r1.nro_cuenta;
                 r_gmovi.estado          := 'N';
                 r_gmovi.reversado       := 'N';
                 r_gmovi.cod_rubro       := v_cod_rubro;
                 r_gmovi.tip_mov_rubro   := 'D';
                 pag_gen.pr_ins_ge_movimiento(r_gmovi);
           ELSIF v_cta_bancaria is not null then
                   v_nro_secuencia  := nvl(v_nro_secuencia, 0) + 1;

                   pag_cta.pr_set_cod_rubro(pac_che.fu_obt_rub_cta_ban(v_cta_bancaria), 'D');

                   pag_cta.pr_act_operacion(v_cta_bancaria,
                                            v_hor_cobro, --HORA
                                            'C',
                                            r1.cod_moneda,
                                            r1.mto_cobrado,
                                            r1.cod_tra_padre,--COD_TRA_PADRE
                                            602,
                                            v_nro_documento,
                                            NULL, --COTIZACION
                                            r1.cod_ofi_origen, --cod_ofi_origen
                                            r1.cod_mod_padre,
                                            r1.cod_mad_padre,
                                            null, --cod_tasa
                                            null, --val_tasa
                                            'Cobro de cuenta '||r1.nro_cuenta,
                                            'S', --emi_aviso
                                            v_nro_secuencia,
                                            r1.fecha);

                   If pag_cta.fu_obt_cod_error() <> 0 then
                      raise_application_error(-20002,'Al hacer el debito en la cuenta bancaria / para el prestamo '||v_cta_bancaria||'/'||r1.nro_cuenta);
                   End if;

           ELSE
                 -- genero movimiento por el cobro en efectivo --
                 IF v_tip_pago = '1' THEN
                   --Efectivo.
                   v_nro_secuencia         := nvl(v_nro_secuencia, 0) + 1;
                   r_gmovi.cod_usuario     := r1.usu_insercion;
                   r_gmovi.hora            := v_hor_cobro;
                   r_gmovi.fecha           := v_fec_actual;
                   r_gmovi.nro_secuencia   := v_nro_secuencia;
                   r_gmovi.cod_modulo      := r_ctapre.cod_modulo;
                   r_gmovi.cod_modalidad   := r_ctapre.cod_modalidad;
                   r_gmovi.cod_oficina     := r1.cod_ofi_origen;
                   r_gmovi.cod_moneda      := r_ctapre.cod_moneda;
                   r_gmovi.fec_valor       := r1.fecha;
                   r_gmovi.cod_tra_padre   := v_cod_tra_padre;
                   r_gmovi.cod_mod_padre   := r_ctapre.cod_modulo;
                   r_gmovi.cod_mad_padre   := r_ctapre.cod_modalidad;
                   r_gmovi.nro_caja        := NULL;
                   r_gmovi.cod_transaccion := 740;
                   r_gmovi.monto           := r1.mto_cobrado;
                   r_gmovi.nro_documento2  := NULL;
                   r_gmovi.nro_documento3  := r1.nro_cuota_desde;
                   r_gmovi.cod_ofi_origen  := r1.cod_ofi_origen;
                   r_gmovi.emi_aviso       := 'S';
                   r_gmovi.concepto        := 'Cobro Prest :' || r1.nro_cuenta;
                   r_gmovi.estado          := 'N';
                   r_gmovi.reversado       := 'N';
                   r_gmovi.cod_rubro       := NULL;
                   r_gmovi.nro_cuenta      := NULL;
                   r_gmovi.tip_mov_rubro   := 'D';
                   pag_gen.pr_ins_ge_movimiento(r_gmovi);
                 ELSIF v_tip_pago = '2' THEN
                   BEGIN
                      SELECT to_char('10' ||substr(v_banco, 2, 3))
                        INTO v_cod_bco_central
                        FROM dual;
                   EXCEPTION
                      WHEN no_data_found THEN
                         v_cod_bco_central := null;
                   END;
                   --Obtener el codigo de banco, ya que no coincide con el listado del BCP.
                   BEGIN
                      SELECT cod_banco
                        INTO v_cod_banco
                        FROM ge_bancos
                       WHERE cod_bco_central = v_cod_bco_central;
                   EXCEPTION
                      WHEN no_data_found THEN
                         v_cod_retorno := '008';
                   END;
                   if v_cod_retorno = '000' then
                      v_nro_secuencia         := v_nro_secuencia + 1;
                      r_gmovi.cod_usuario     := r1.usu_insercion;
                      r_gmovi.hora            := v_hor_cobro;
                      r_gmovi.fecha           := v_fec_actual;
                      r_gmovi.nro_secuencia   := v_nro_secuencia;
                      r_gmovi.cod_modulo      := r_ctapre.cod_modulo;
                      r_gmovi.cod_modalidad   := r_ctapre.cod_modalidad;
                      r_gmovi.cod_oficina     := r1.cod_ofi_origen;
                      r_gmovi.cod_moneda      := r_ctapre.cod_moneda;
                      r_gmovi.fec_valor       := r1.fecha;
                      r_gmovi.cod_tra_padre   := v_cod_tra_padre;
                      r_gmovi.cod_mod_padre   := r_ctapre.cod_modulo;
                      r_gmovi.cod_mad_padre   := r_ctapre.cod_modalidad;
                      r_gmovi.nro_caja        := NULL;
                      r_gmovi.cod_transaccion := 607; --- Cheques
                      r_gmovi.monto           := r1.mto_cobrado;
                      r_gmovi.nro_documento2  := v_nro_cheque;
                      r_gmovi.nro_documento3  := r1.nro_cuota_desde;
                      r_gmovi.cod_ofi_origen  := r1.cod_ofi_origen;
                      r_gmovi.emi_aviso       := 'S';
                      r_gmovi.concepto        := 'Cobro Prest :' || r1.nro_cuenta || ' Banco : ' ||
                                                 v_cod_banco;
                      r_gmovi.estado          := 'N';
                      r_gmovi.reversado       := 'N';
                      r_gmovi.cod_rubro       := NULL;
                      r_gmovi.nro_cuenta      := NULL;
                      r_gmovi.tip_mov_rubro   := NULL;
                      -- Recuperar datos de la retencion
                      pag_cta.pr_obt_retencion(r1.fecha, r1.nro_cuenta, r_ctapre.cod_modulo, r_ctapre.cod_modalidad,
                                               607, r_ctapre.cod_moneda, r_gmovi.cod_retencion,
                                               r_gmovi.fec_fin_retencion);
                      pag_gen.pr_ins_ge_movimiento(r_gmovi);
                   END IF;
                 END IF;
           END IF;
       END IF;
       
       v_lugar:= 'al hacer el cobro en cta. nro '|| r1.nro_cuenta;
              
       -- Procesa los cobros realizados fuera de hora.
       if r1.cod_tra_padre = 359 then
           v_nro_secuencia:= NVL(v_nro_secuencia,0) +1;
           pap_pre.pr_can_prestamo(r1.nro_cuenta, r1.mto_cobrado, 'N', r1.cod_ofi_origen, 'T', r1.fecha,
                                        v_hor_cobro, v_nro_secuencia);
       else
         BEGIN
           v_nro_secuencia:= NVL(v_nro_secuencia,0) +1;
           pap_pre.pr_cob_prestamo(r1.nro_cuenta,
                                   r1.mto_cobrado,
                                   'N',
                                   r1.cod_ofi_origen,
                                   r1.nro_cuota_desde,
                                   r1.nro_cuota_hasta,
                                   'Pago de Cuota', --concepto
                                   r1.fecha,
                                   v_hor_cobro, -- ESTE PARAMETRO ES IN OUT (Devuelve la nueva hora generada)
                                   v_nro_secuencia,
                                   r1.cod_tra_padre,
                                   r1.cod_mod_padre,
                                   r1.cod_mad_padre,
                                   'N', 
                                   NULL,
                                   'N',
                                   'N',
                                   'N',
                                   r1.usu_insercion);
        EXCEPTION
          WHEN OTHERS THEN
            v_error:=upper(replace(sqlerrm, 'ORA-20000: ', ''));
            IF v_error = 'EL MONTO A PAGAR DEBE CUBRIR POR LO MENOS LOS CARGOS.' THEN
              rollback to savepoint v_sav_point;
              -- se pasa a un Estado = (E)rror para no afectar el cursor C2
              update it.pr_cobros_noc w 
                 set w.estado = 'E' 
               where w.nro_cuenta=r1.nro_cuenta and w.mto_cobrado = r1.mto_cobrado
                 and w.nro_cuota_desde = r1.nro_cuota_desde and w.nro_cuota_hasta = r1.nro_cuota_desde;
               PRG_ACT_LOG_PROCESOS('PRP_COB_PRE_NOCTURNOS','1',trunc(sysdate),to_char(sysdate,'hh24:mi:ss'), to_char(sysdate,'hh24:mi:ss'),'Mto. Cargo supera Mto. Abonado Cta:'||r1.nro_cuenta||' Mto: ' ||r1.mto_cobrado);      
              goto siguiente_registro;
            END IF;
          END;                           
        end if;
        v_lugar := 'al actualizar los movimientos en cta. nro '||r1.nro_cuenta;
        
     -- === INICIO DE LA ALINEACION DEL DEBITO ===
        -- 1. Buscamosy  el usuario real generado por PAP_PRE (Desglose)
        -- Lo hacemos SIEMPRE, porque PAP_PRE suele cambiar el usuario (ej. LOANS a LOANS_1)
        begin
            SELECT m.cod_usuario
              INTO v_usu_pap_pre
              FROM ge_movimientos m
             WHERE m.fecha = v_fec_actual
               AND m.hora = v_hor_cobro
               AND m.nro_cuenta = r1.nro_cuenta
               AND m.nro_documento3 = r1.nro_cuota_hasta
               AND rownum = 1; 
          exception
            when no_data_found then
              PRG_ACT_LOG_PROCESOS(
                'PRP_COB_PRE_NOCTURNOS',
                '1',
                trunc(sysdate),
                to_char(sysdate,'hh24:mi:ss'),
                to_char(sysdate,'hh24:mi:ss'),
                'ALERTA: Movimiento de cobro no encontrado para alineacion. Cta: ' || r1.nro_cuenta || 
                ' Fecha: ' || v_fec_actual || ' Hora: ' || v_hor_cobro ||
                '. Usando identidad original como fallback.'
              );
              v_usu_pap_pre := r1.usu_insercion;
            when others then
              raise_application_error(
                -20998,
                'Error inesperado buscando movimiento de cobro para alineacion (Cta: ' || r1.nro_cuenta || 
                '): ' || sqlerrm
              );
          end;

        -- 2. Si la hora O el usuario son distintos a los originales del débito, lo alineamos
        if v_hor_cobro <> r1.hora or v_usu_pap_pre <> r1.usu_insercion then
           
           -- 3. Actualizamos el débito nocturno usando su PK original exacta y reforzando con la cuenta
           update ge_movimientos m
              set m.fecha = v_fec_actual,
                  m.hora = v_hor_cobro,
                  m.cod_usuario = v_usu_pap_pre,
                  m.nro_secuencia = nvl(v_nro_secuencia,0) + 1
            where m.fecha = r1.fecha
              and m.hora = r1.hora
              and m.cod_usuario = r1.usu_insercion
              and instr(m.concepto, r1.nro_cuenta) > 0;
              
        end if;
        -- === FIN DE LA ALINEACION ===

       ---
       if v_hor_cobro <> r1.hora then
         UPDATE PR_COBROS_NOC
            SET ESTADO = 'P',
                FEC_PROCESO = v_fec_actual,
                HORA = v_hor_cobro
          WHERE ESTADO = 'I'
            AND rowid = r1.registro;
       else
         UPDATE PR_COBROS_NOC
            SET ESTADO = 'P',
                FEC_PROCESO = v_fec_actual
          WHERE ESTADO = 'I'
            AND rowid = r1.registro;
       end if;
       <<siguiente_registro>>
       null;
   END LOOP;

   FOR R2 IN C2 LOOP
       v_fecha := pag_cal.fu_obt_fec_ant_hab(r2.fecha, fug_obt_ofi_usuario(r2.usu_insercion));
       v_nro_secuencia := r2.nro_secuencia;
       if instr(fug_obt_pardinamico('COD_USU_PAG_SER'),R2.usu_insercion)>0 then
           v_concepto := 'Reversion.Pag.Prest.'|| R2.usu_insercion;

           BEGIN
              SELECT MAX(hora)
                INTO v_hora
                FROM pr_cobros c
               WHERE c.nro_cuenta = r2.nro_cuenta
                 AND (c.nro_cuota = r2.nro_cuota_desde)
                 and nvl(c.mto_capital, 0) + nvl(c.mto_interes, 0) +
                     nvl(c.mto_int_documentado, 0) +
                     nvl(c.mto_int_moratorio, 0) +
                     nvl(c.mto_int_mor_interes, 0) +
                     nvl(c.mto_int_mor_adelantado, 0) +
                     nvl(c.mto_int_punitorio, 0) + nvl(c.mto_cargo, 0) +
                     nvl(c.mto_impuesto, 0) +
                     nvl(c.mto_int_descontado, 0) = -(r2.mto_cobrado)
                 AND c.fecha = v_fecha;
             EXCEPTION
                  WHEN no_data_found THEN
                       raise_application_error(-20000,'Error al buscar cobro para reversar '||r2.nro_cuenta);
             END;
             prg_rev_operacion(v_fecha, v_hora, r2.usu_insercion, r2.cod_mod_padre,
                               r2.cod_mad_padre, r2.cod_tra_padre, USER,
                               to_char(SYSDATE, 'HH24:MI:SS'), 'N', v_concepto, NULL);
       END IF;
       UPDATE PR_COBROS_NOC
          SET ESTADO = 'P',
              FEC_PROCESO = r2.fecha
        WHERE ESTADO = 'I'
          AND rowid = r2.registro;
   END LOOP;
   ---------------------------------------------------------
   -- CIE-125 Se asigna el estado I para las ctas con error
   ---------------------------------------------------------
   BEGIN
    UPDATE it.pr_cobros_noc 
      SET estado = 'I' 
    WHERE estado = 'E';
   EXCEPTION
     WHEN OTHERS THEN 
     NULL;
   END;
   --
exception
  when others then
    raise_application_error(-20000,'Error '||v_lugar||' '||v_nro_secuencia||' '||sqlerrm);
END;
/
