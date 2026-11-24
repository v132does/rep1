CREATE OR REPLACE PROCEDURE IT.PRP_DEB_AUTOMATICO_ATR
(
   p_cod_persona IN VARCHAR2 DEFAULT NULL,
   p_nro_cuenta  IN VARCHAR2 DEFAULT NULL,
   p_nro_cta_debito IN VARCHAR2 DEFAULT NULL
) IS
   /* PCCDEEVO-1046: PROCESO NUEVO PARA DEBITAR DE LAS CUENTAS RELACIONADAS COMO PRINCIPAL O INDEPENDIENTE 
	  A LOS TITULARES DE LAS CUENTAS QUE NO SE PUDIERON DEBITAR POR EL PRP_DEB_AUTOMATICO NORMAL EL DIA ANTERIOR O SEA  
	  A LAS CUENTAS CON DEBITO AUTOMATICO Y UN ATRASO DE 1 O MAS DIAS*/
   -- variables para rollback
   v_rol_referencia varchar2(30) := 'inicio';
   v_rol_ejecuta    varchar2(1) := 'N';
   v_commitea       varchar2(1) := 'N';
   v_sig_prestamo   varchar2(1) := 'N';
   /* Inserta movimiento con error. */
   PROCEDURE lp_ins_mov_error;
   v_fecha         ge_calendarios.fec_actual%TYPE;
   v_hora          ge_movimientos.hora%TYPE;
   v_cod_modulo    ba_modulos.cod_modulo%TYPE;
   v_cod_tra_padre ge_transacciones.cod_transaccion%TYPE;
   v_cod_mon_local ba_monedas.cod_moneda%TYPE;
   v_nro_secuencia ge_movimientos.nro_secuencia%TYPE;
   r_gmovi         ge_movimientos%ROWTYPE;
   --- Datos para recuperar deuda del prestamo
   v_pag_parcial  VARCHAR2(01) := 'S';
   v_sal_cobrado  pr_cuotas.sal_capital%TYPE;
   v_sal_capital  pr_cuotas.sal_capital%TYPE;
   v_sal_interes  pr_cuotas.sal_interes%TYPE;
   v_sal_int_ade  pr_cuotas.sal_int_documentado%TYPE;
   v_mora         pr_cuotas.sal_interes%TYPE;
   v_mora_interes pr_cuotas.sal_interes%TYPE;
   v_mora_int_ade pr_cuotas.sal_interes%TYPE;
   v_impuesto     pr_cuotas.sal_interes%TYPE;
   v_cargo        pr_cuotas.sal_interes%TYPE;
   v_cargo_iva    pr_cuotas.sal_interes%TYPE;
   --v_seguro         pr_cuotas.sal_interes%type;
   v_punitorio      pr_cuotas.sal_interes%TYPE;
   v_int_descontado pr_cuotas.sal_interes%TYPE;
   v_mto_deuda      pr_cuotas.sal_capital%TYPE;
   v_nro_cuenta_ant pr_cta_prestamos.nro_cuenta%TYPE;
   v_dias_mora      NUMBER(05);
   --- Datos para utilizar la cuenta de débito
   v_mto_deu_deb    ge_cuentas.sal_contable%TYPE;
   v_cot_mon_pre    ge_cotizaciones.val_conversion%TYPE;
   v_cot_mon_deb    ge_cotizaciones.val_conversion%TYPE;
   v_nvo_estado     ge_cuentas.estado%TYPE;
   v_sal_disponible ge_cuentas.sal_contable%TYPE;
   v_procesa        VARCHAR2(01);
   v_error          VARCHAR2(10);
   v_mensaje        VARCHAR2(1000);
   v_imp_cuenta     pr_cuotas.sal_interes%TYPE;
   v_lin_sobregiro  NUMBER(18, 2) := 0;
   v_con_debito     ge_movimientos.concepto%type;
   v_cod_causa     ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('GEN_COD_CAU_INH_COBRO');   
   v_PRE_ATR_DEB_AUT_CUENTAS_REL ge_par_dinamicos.parametro%type := nvl(to_number(fug_obt_pardinamico('PRE_ATR_DEB_AUT_CUENTAS_REL')),                                                                       0);
   v_PRE_COB_AUT_ATR_PER_FISICAS ge_par_dinamicos.parametro%type := fug_obt_pardinamico('PRE_COB_AUT_ATR_PER_FISICAS');
   v_cod_tra_aguinaldo  ge_transacciones.cod_transaccion%type;
   v_mto_aguinaldo      number := 0;
   v_tot_aguinaldo      number := 0;
   v_fec_ini_mes        date;
   v_cod_ente           ah_cta_vistas.cod_ente%type := null;
   v_dia_aguinaldo      ge_par_dinamicos.val_parametro%type;
   v_fec_aguinaldo      date;
   v_blo_sal_agui       varchar2(1) := nvl(fug_obt_pardinamico('BLO_DEB_SAL_AGUINALDO'),'N');
   --RI: 15/12/2010: Parametro creado para determinar si se procesa cuenta de nomina
   --v_pro_cta_nomina varchar2(1) := nvl(fug_obt_pardinamico('PRO_CTA_NOMINA'),'S'); COMENTADO PORQUE NO ESTÁ IMPLEMENTADO AÚN EL REQUERIMIENTO A PEDIDO DE VCAPRA EL 04/03/2011
   --- Cursor de cuentas de préstamos con débito automático

   --- Toma todas las cuotas atrasadas de todos los préstamos hasta la fecha actual, y además ordena por
   --- la fecha de vencimiento y el saldo de la cuota para el débito
   --- Procedimiento Modificado para Optimización AP 3006
   CURSOR c_debitos IS
      SELECT distinct pr.nro_cuenta,
             cl.cod_persona,
             pr.nro_cta_debito,
             pr.dia_atraso,
             pr.cod_oficina,
             cu.nro_cuota,
             pr.cod_moneda,
             pr.cod_modulo,
             pr.cod_modalidad,
             cu.nro_documento,
                    (SELECT  MAX(nro_cuota) cuo_hasta
                FROM pr_cuotas
               WHERE fec_vencimiento < v_fecha
                 AND estado <> 'N'
                 AND nro_cuenta = pr.nro_cuenta
                 AND NVL(sal_capital, 0) + NVL(sal_interes, 0) + NVL(sal_int_documentado, 0) > 0) max_cuota,
            (NVL(cu.sal_capital, 0) + NVL(cu.sal_interes, 0) + NVL(cu.sal_int_documentado, 0)) sal_tot_cuota,
             cu.fec_vencimiento
        FROM ge_cta_clientes cl,
             ge_clientes      c,
             ba_usuarios      u,
             pr_cta_prestamos pr,
             pr_cuotas cu,
             ge_cta_clientes  gd,
             ge_par_dinamicos pd
       WHERE pr.nro_cuenta = cu.nro_cuenta
         AND pr.nro_cuenta = cl.nro_cuenta
         /*PCCDEEVO-1046: Parametro que guarda los dias de atraso minimos a tener en cuenta
         para debitar de las Cuentas Relacionadas.*/
         And PR.DIA_ATRASO >= v_PRE_ATR_DEB_AUT_CUENTAS_REL
         AND NVL(fug_obt_pardinamico('MAD_ANTICIPOS', pr.cod_modulo,pr.cod_modalidad),'N') = 'N' --No debe incluir Anticipos al Personal
         AND cl.relacion =  'P' --- Cliente principal
         -- Inicialmente solo personas fisicas.
         AND ((pag_gen.FU_ES_PER_FISICA(cl.cod_persona) = 'S' AND
           v_PRE_COB_AUT_ATR_PER_FISICAS = 'S') OR
           (v_PRE_COB_AUT_ATR_PER_FISICAS = 'N'))
         AND pr.estado <> 'N' --- Préstamos no cancelados
         and (gd.nro_cuenta = p_nro_cta_debito or p_nro_cta_debito is null)
         and gd.relacion in('P','O')
         and gd.cod_modalidad in(31,41,334)
         and cl.cod_persona = c.cod_persona
         and c.cod_usu_oficial = u.cod_usuario
         and nvl(fug_obt_pardinamico('PRE_COB_AUT_OFI_EXCLUIDA',
                                     PR.COD_MODULO,
                                     NULL,
                                     NULL,
                                     U.COD_OFICINA),
                 'N') <> 'S'
         and pd.parametro = 'PRE_MAD_COB_AUTOMATICO'
         and pd.cod_modulo = pr.cod_modulo
         and pd.cod_modalidad = pr.cod_modalidad
         and pd.val_parametro = 'S'
         and gd.cod_persona = cl.cod_persona        
         AND (nvl(pr.nro_cta_debito, p_nro_cta_debito) = p_nro_cta_debito or p_nro_cta_debito is null)
         AND cu.fec_vencimiento <= v_fecha
         AND cu.nro_cuota > 0
         AND cu.estado <> 'N'
         and nvl(fug_obt_paradicional(pr.nro_cuenta, 'EXC_CTA_COB_AUTOMATICO'),
               'N') <> 'S'
         AND (p_nro_cuenta  IS NULL OR pr.nro_cuenta = p_nro_cuenta)
         AND (p_cod_persona IS NULL OR cl.cod_persona = p_cod_persona)
         and not EXISTS
         (SELECT DISTINCT ('S')
                  FROM GE_PER_INHIBIDAS A, GE_CAUSALES B
                 WHERE A.COD_CAUSA = B.COD_CAUSA
                   AND A.ESTADO = 'I'
                   AND A.COD_PERSONA = CL.COD_PERSONA
                   AND INSTR(v_cod_causa,
                             a.COD_CAUSA) > 0
                UNION ALL
                SELECT 'S'
                  FROM GE_CUENTAS A, GE_CTA_CLIENTES B, GE_PER_INHIBIDAS C
                 WHERE A.NRO_CUENTA = B.NRO_CUENTA
                   AND B.COD_PERSONA = C.COD_PERSONA
                   and b.nro_cuenta = cl.nro_cuenta
                   and c.estado = 'I'
                   and b.relacion <> 'P'
                   and INSTR(v_cod_causa,
                             C.COD_CAUSA) > 0
                   AND ROWNUM = 1) 
       --ORDER BY nro_cuenta, cu.fec_vencimiento;
       ORDER BY  cu.fec_vencimiento asc;
   /* Inserta movimiento con error. */
   /*Cursor para recuperar cuentas relacionadas tipo Principal o Indistinto del titular del Prestamo.*/
Cursor cta_relacionadas(p_cod_persona_rel In ge_clientes.cod_persona%Type,
                        p_cta_debito_rel  In ge_cuentas.nro_cuenta%Type) Is
    Select a.Nro_Cuenta,
           a.Cod_Persona,
           a.Relacion,
           p.tipo,
           Decode(a.cod_modulo,
                  3,
                  (b.sal_total - (b.sal_bloqueado + b.sal_retenido)),
                  4,
                  (c.sal_total - (c.sal_retenido + c.sal_bloqueado))) sal_total,
           a.Cod_Modulo,
           a.Cod_Modalidad
      From Ge_Cta_Clientes   a,
           ge_cuentas        d,
           Ah_Cta_Vistas     b,
           Cc_Cta_Corrientes c,
           ba_personas       p
     Where (a.Relacion = 'P' OR
           ((a.relacion = 'O' AND P.TIPO = 'F' AND
           pag_gen.FU_ES_PER_FISICA(FUG_OBT_CLI_PRINCIPAL(A.NRO_CUENTA)) = 'S') or
           (a.relacion = 'O' AND P.TIPO = 'J' AND
           pag_gen.FU_ES_PER_FISICA(FUG_OBT_CLI_PRINCIPAL(A.NRO_CUENTA)) = 'N')))
       And a.Nro_Cuenta = b.Nro_Cuenta(+)
       and a.cod_persona = p.cod_persona
       -- Moneda igual a la moneda de la cuenta debito o en su defecto de la cuenta atrasada a cobrar.       
       and fug_obt_mon_cta(a.nro_cuenta) = fug_obt_mon_cta(p_cta_debito_rel)
       And a.nro_cuenta = d.nro_cuenta
       And a.nro_cuenta != p_cta_debito_rel
       And a.Nro_Cuenta = c.Nro_Cuenta(+)
       And a.Cod_Modalidad In (31, 41,334)
       AND d.cod_sub_modalidad <> 6
       AND D.ESTADO not IN ('A', 'C', 'T', 'D')
       And a.cod_persona = p_cod_persona_rel
       And Decode(a.cod_modulo,
                  3,
                  (b.sal_total - (b.sal_bloqueado + b.sal_retenido)),
                  4,
                  (c.sal_total - (c.sal_retenido + c.sal_bloqueado))) > 0
     ORDER BY 5 DESC; --dydmr-12385 al ordenar estaba tomando la columna equivocada que deberia ser el saldo desc
   PROCEDURE lp_ins_mov_error IS
   BEGIN
      v_nro_secuencia := v_nro_secuencia + 1;
      --- Cargar registro de movimientos
      r_gmovi.fecha         := v_fecha;
      r_gmovi.fec_valor     := v_fecha;
      r_gmovi.cod_usuario   := USER;
      r_gmovi.hora          := v_hora;
      r_gmovi.nro_secuencia := v_nro_secuencia;
      r_gmovi.cod_tra_padre := v_cod_tra_padre;
      r_gmovi.reversado     := 'N';
      r_gmovi.emi_aviso     := 'N';
      r_gmovi.protegido     := 'N';
      pag_gen.pr_ins_ge_movimiento(r_gmovi);
   END;
   FUNCTION lf_obt_mto_aguinaldo(p_nro_cta varchar2) return number IS
    BEGIN
      select sum(a.MONTO)
        into v_mto_aguinaldo
        from gv_movimientos a
       where a.FECHA >= v_fec_ini_mes
         and a.fecha <= v_fecha
         and a.COD_TRA_PADRE = v_cod_tra_aguinaldo
         and a.COD_TRANSACCION = 602
         and a.NRO_CUENTA = p_nro_cta
         and a.REVERSADO = 'N';
      return nvl(v_mto_aguinaldo,0);
    exception
      when no_data_found then
        return 0;
      when others then
        return 0;
    END;

    FUNCTION lf_obt_fec_aguinaldo(p_nro_cta varchar2) return date IS
      v_fec_aguinaldo date;
    BEGIN
      select max(a.fecha)
        into v_fec_aguinaldo
        from gv_movimientos a
       where a.FECHA >= v_fec_ini_mes
         and a.fecha <= v_fecha
         and a.COD_TRA_PADRE = v_cod_tra_aguinaldo
         and a.COD_TRANSACCION = 602
         and a.NRO_CUENTA = p_nro_cta
         and a.REVERSADO = 'N';
      return v_fec_aguinaldo;
    exception
      when no_data_found then
        return null;
      when others then
        return null;
    END;

   /* 24/12/2013 PN DI: Se creó el procedimiento interno con el fin de unificar
                        lo usuarios de los movimientos, debido que en el pag_cta
                        está mal seteado y genera movimientos con usuarios distintos,
                        esto hace que exista un problema al querer reversar (SPI 2883)*/
   PROCEDURE  pr_ver_mov_debito IS

     v_cod_usuario ge_movimientos.cod_usuario%type;
     cursor c_mov_debito is
            select x.rowid registro, cod_usuario
             from ge_movimientos x
            where x.fecha = v_fecha
              and x.hora = v_hora
              and x.cod_usuario <> user
              and cod_tra_padre = v_cod_tra_padre
              and x.cod_transaccion = 503
              and concepto = v_con_debito;

    cursor c_mov_transfer is
         select x.rowid reg_tran
           from ge_movimientos x
          where fecha = v_fecha
            and hora = v_hora
            and cod_usuario = v_cod_usuario
            and cod_tra_padre = 309;

   BEGIN
     for mov in c_mov_debito loop
       v_cod_usuario := mov.cod_usuario;

       update ge_movimientos x
          set cod_usuario = user
        where x.rowid = mov.registro;

       for tra in c_mov_transfer loop

         update ge_movimientos
            set cod_usuario = user
          where rowid = tra.reg_tran;
       end loop;
     end loop;
  END;

   /* 22/04/2016 GC : Se creó el procedimiento interno autonomo, con el fin de registrar
                      los errores en el proceso de debito automatico de prestamos*/
   PROCEDURE pr_ins_log_error(p_nro_cuenta   tm_log_nominas.nro_cuenta%type,
                              p_monto        tm_log_nominas.monto%type,
                              p_sal_total    tm_log_nominas.sal_total%type,
                              p_lugar        tm_log_nominas.lugar%type,
                              p_observacion  tm_log_nominas.observacion%type)
    is
    pragma autonomous_transaction;
    begin
      insert into tm_log_nominas
      (nro_cuenta, monto, sal_total, lugar, observacion, fec_insercion)
      values
      (p_nro_cuenta, p_monto, p_sal_total, p_lugar, p_observacion, sysdate);
      commit; -- este commit solo afecta a la transaccion autonoma
    end ;

BEGIN

/*   IF P_CTA_DEBITO IS NULL THEN
      dbms_mview.refresh('PV_CUO_PENDIENTES');
      dbms_mview.refresh('PV_DEB_AUTOMATICO');
   END IF;*/

   --- Recuperar datos de fecha calendario
   v_cod_modulo := 6;
   v_fecha      := pag_cal.fu_obt_fec_actual(v_cod_modulo);
   --RI: 18/10/2010: Si no se ejecuta desde el cierre tomar la hora actual
   --IF nvl(pae_cnf.g_programa, 'X') = 'GPPROFIN' or nvl(pae_cnf.g_programa, 'X') = 'GPPAGSUE' THEN
      --cierre
      --v_hora := fug_ini_hora(SYSDATE, 'HH24:MI:SS');
   --ELSE
      v_hora := to_char(SYSDATE, 'HH24:MI:SS');
   --END IF;

   v_nro_secuencia  := 0;
   v_cod_tra_padre  := 364;
   v_cod_mon_local  := pag_gen.fu_obt_mon_local;
   v_nro_cuenta_ant := 'x';
   v_sig_prestamo   := 'N';
   v_dia_aguinaldo  := nvl(fug_obt_pardinamico('CAN_DIA_DEB_AGUINALDO'),0);

   FOR pre IN c_debitos Loop
     For rel In cta_relacionadas(pre.cod_persona, nvl(pre.nro_cta_debito, pre.nro_cuenta)) Loop
      /*DYDMR-12385 si se hacen cobros parciales para una misma cuenta se debe hacer con una hora diferente 
      para que no de error al insertar en pr_cobros, al igual que la secuencia se debe reiniciar para que 
      sea un movimiento aparte el cobro de la otra cuenta relacionada*/
      v_hora := fug_obt_hor_disponible(v_fecha,v_hora,user,'N');
      v_nro_secuencia  := 0;
      -- Control de rollback
      v_rol_referencia := pre.nro_cuenta||pre.nro_cuota;
      prg_cre_savepoint(v_rol_referencia);
      v_rol_ejecuta    := 'N';
      v_commitea       := 'N';
      --- Inicializar variables auxiliares
      r_gmovi          := NULL;
      v_sal_cobrado    := NULL;
      v_error          := NULL;
      v_mensaje        := NULL;
      v_sal_capital    := NULL;
      v_sal_interes    := NULL;
      v_sal_int_ade    := NULL;
      v_mora           := NULL;
      v_mora_interes   := NULL;
      v_mora_int_ade   := NULL;
      v_punitorio      := NULL;
      v_impuesto       := NULL;
      v_cargo          := NULL;
      v_cargo_iva      := NULL;
      v_int_descontado := NULL;
      --cotización
      v_cot_mon_pre := NULL;
      v_cot_mon_deb := NULL;
      v_cod_ente    := null;
      begin
        select a.cod_ente
          into v_cod_ente
          from ah_cta_vistas a
         where a.nro_cuenta = rel.nro_cuenta;
      exception
        when no_data_found then
          v_cod_ente := null;
        when others then
          v_cod_ente := null;
      end;
      if v_cod_ente is not null and nvl(v_blo_sal_agui,'N') = 'S' then
        v_cod_tra_aguinaldo := fug_obt_parentes(v_cod_ente, 'COD_TRA_PAD_AGUINALDO');
        pag_cal.PR_OBT_DAT_CALENDAR(1);
        v_fec_ini_mes := pag_cal.G_PRI_DIA_MES;
        v_tot_aguinaldo := lf_obt_mto_aguinaldo(rel.nro_cuenta);
        v_fec_aguinaldo := lf_obt_fec_aguinaldo(rel.nro_cuenta);
      end if;

      IF pre.nro_cuenta <> v_nro_cuenta_ant THEN
         --- Para grabar por cada registro procesado y sus movimientos la misma hora
         --v_hora           := pag_gen.fu_obt_sig_segundo(v_hora);
         v_nro_cuenta_ant := pre.nro_cuenta;
         v_sig_prestamo := 'N';
      ELSE
         -- Prestamo es igual al anterior, continua solo si hubo commit(sino esta prendido v_sig_prestamo)
         IF v_sig_prestamo = 'S' then
            GOTO siguiente_registro;
         END IF;
      END IF;

      --- Inicializar registro de movimiento por si da error
      r_gmovi.cod_ofi_origen := pre.cod_oficina;
      r_gmovi.cod_mod_padre  := pre.cod_modulo;
      r_gmovi.cod_mad_padre  := pre.cod_modalidad;
      r_gmovi.nro_documento  := pre.nro_documento;
      r_gmovi.concepto       := 'Debito Prest. Moroso ' || pre.nro_cuenta;

      -- movido esta seccion mas arriba, ya que hay muchas cuentas de debito sin saldo de tal forma a
      -- optimizar el tiempo de procesamiento de prestamos que no tienen saldo minimo para el cobro

      --- Recuperar datos de la cuenta de ahorro
      pag_cta.pr_obt_cuenta(rel.nro_cuenta);
      r_gmovi.cod_modulo      := pag_cta.g_ctas.cod_modulo;
      r_gmovi.cod_modalidad   := pag_cta.g_ctas.cod_modalidad;
      r_gmovi.nro_cuenta      := rel.nro_cuenta;
      r_gmovi.cod_moneda      := pag_cta.g_ctas.cod_moneda;
      r_gmovi.cod_transaccion := 503;
      IF pag_cta.g_cod_error <> 0 THEN
       pr_ins_log_error(pre.nro_cuenta,
                        pre.sal_tot_cuota,
                        0,
                        'PRP_DEB_AUTOMATICO_ATR 1',
                        substr(pag_cta.FU_OBT_MSJ_ERROR, 1, 299)); -- 22/04/2016 GC
         GOTO siguiente_registro;
      END IF;
      --- Verificar monedas ----
      IF pag_cta.g_ctas.cod_moneda <> pre.cod_moneda AND -- Cta. Débito Vs Préstamo
         pag_cta.g_ctas.cod_moneda <> v_cod_mon_local AND -- Cta. Débito Vs Local
         pre.cod_moneda <> v_cod_mon_local THEN
         GOTO siguiente_registro;
      END IF;
      --- Calculo el total a debitar en la moneda de la cuenta de debito
      pag_gen.pr_con_mon_a_moneda(pre.cod_moneda, pag_cta.g_ctas.cod_moneda, pre.sal_tot_cuota,
                                  v_mto_deu_deb, v_cot_mon_pre, v_cot_mon_deb);
      --- Verificar parámetro de pago para identificar el monto de la deuda
      v_pag_parcial := fug_obt_pardinamico('PAG_COB_AUT', pre.cod_modulo, pre.cod_modalidad,
                                           pre.cod_moneda, pre.cod_oficina);
    
      --- Recuperar deuda a la fecha del proceso
      --- Recuperar deuda de la cuota
      pap_pre.pr_obt_deu_prestamo(pre.nro_cuenta, v_fecha, pre.nro_cuota, pre.nro_cuota,
                                  -- pre.cuo_hasta, F.Q. debe traer solo la deuda de la cuota que trae el cursor
                                  pre.cod_oficina, v_sal_cobrado, v_error, v_mensaje, v_sal_capital,
                                  v_sal_interes, v_sal_int_ade, v_mora, v_mora_interes,
                                  v_mora_int_ade, v_punitorio, v_impuesto, v_cargo, v_cargo_iva,
                                  v_int_descontado, v_dias_mora, v_cod_tra_padre);
      IF v_error <> 0 THEN
         --NO GENERAR MOV CON ERROR XQ DA PROBLEMAS EN ASIENTOS
         ---raise_application_error(-20000, v_mensaje); OJO por ahora error ver + adelante
         /*         r_gmovi.estado    := 'E';
                  r_gmovi.cod_error := fug_obt_err_sueldos(pag_cta.g_cod_error, 'A');
                  --- Grabar movimiento con error
                  lp_ins_mov_error;
         */ --- Ir al Siguiente
         v_rol_ejecuta := 'S';
         pr_ins_log_error(pre.nro_cuenta,
                          pre.sal_tot_cuota,
                          0,
                          'PRP_DEB_AUTOMATICO ATR 3',
                          'Error al recuperar deuda del prestamo'); -- 22/04/2016 GC
         GOTO siguiente_registro;
      END IF;
      v_mto_deuda := nvl(v_sal_capital, 0) + nvl(v_sal_interes, 0) + nvl(v_sal_int_ade, 0) +
                     nvl(v_mora, 0) + nvl(v_mora_interes, 0) + nvl(v_mora_int_ade, 0) +
                     nvl(v_punitorio, 0) + nvl(v_impuesto, 0) + nvl(v_cargo, 0);
      if v_mto_deuda = 0 then
        GOTO siguiente_registro;
      end if;
      /* dydmr-12385 si con la primera cuenta relacionada ya se cobro toda la deuda entonces al recuperar la deuda
      0 restante con la relacionada dos pasar directo al siguente registro porque al continuar con deuda 0 da error el cobro 
      y pasa al siguente prestamo */
      --- Calculo el total a debitar en la moneda de la cuenta de debito
      pag_gen.pr_con_mon_a_moneda(pre.cod_moneda, pag_cta.g_ctas.cod_moneda, v_mto_deuda,
                                  v_mto_deu_deb, v_cot_mon_pre, v_cot_mon_deb);
      IF (v_pag_parcial = 'N' AND
         nvl(pag_cta.g_ctas.sal_disponible, 0) + nvl(pag_cta.g_ctas.sal_dis_combinada, 0) +
         v_lin_sobregiro < nvl(v_mto_deu_deb, 0)) OR
         (v_pag_parcial = 'S' AND
         (nvl(pag_cta.g_ctas.sal_disponible, 0) + nvl(pag_cta.g_ctas.sal_dis_combinada, 0) +
         v_lin_sobregiro <= 0 OR
         nvl(pag_cta.g_ctas.sal_disponible, 0) + nvl(pag_cta.g_ctas.sal_dis_combinada, 0) +
         v_lin_sobregiro <
         fug_obt_pardinamico('MIN_COB_AUT', pre.cod_modulo, pre.cod_modalidad, pre.cod_moneda,
                               pre.cod_oficina))) THEN

        pr_ins_log_error(pre.nro_cuenta,
                pre.sal_tot_cuota,
                nvl(pag_cta.g_ctas.sal_disponible, 0) + nvl(pag_cta.g_ctas.sal_dis_combinada, 0),
                'PRP_DEB_AUTOMATICO ATR 4',
                'Saldo no cubre totalidad de la deuda'); -- 22/04/2016 GC
         --- Solo se cobra si el saldo de la cuenta cubre toda la deuda
         GOTO siguiente_registro;
      END IF;
     --calcula impuesto si corresponde y genera movimiento, en moneda de cta débito
      BEGIN
         prg_ver_cob_cargos(rel.nro_cuenta, pre.nro_cuenta, pre.cod_modulo, pre.cod_modalidad,
                            pre.cod_oficina,
                            --oficina del préstamo, oficina origen
                            pag_cta.g_ctas.cod_moneda, v_mto_deu_deb,
                            'Cobro aut. Préstamo atr ' || pre.nro_cuenta, NULL,
                            --v_nro_documento,
                            v_fecha, v_hora, v_imp_cuenta, v_nro_secuencia, 'N'); -- no procesa
      EXCEPTION
         WHEN OTHERS THEN
            v_imp_cuenta := 0; --para que no caiga
      END;
      IF v_pag_parcial = 'S' AND
         (nvl(pag_cta.g_ctas.sal_disponible, 0) + nvl(pag_cta.g_ctas.sal_dis_combinada, 0) +
         v_lin_sobregiro) < nvl(v_mto_deu_deb, 0) + nvl(v_imp_cuenta, 0) THEN
         
         v_imp_cuenta := (nvl(pag_cta.g_ctas.sal_disponible, 0) +
                         nvl(pag_cta.g_ctas.sal_dis_combinada, 0) + v_lin_sobregiro) /
                         nvl(v_mto_deu_deb, 0) * nvl(v_imp_cuenta, 0);
                         
         IF pre.cod_moneda = pag_gen.fu_obt_mon_local THEN
            v_imp_cuenta := ceil(v_imp_cuenta);
         END IF;
         
         v_mto_deu_deb := (nvl(pag_cta.g_ctas.sal_disponible, 0) +
                          nvl(pag_cta.g_ctas.sal_dis_combinada, 0) + v_lin_sobregiro) -
                          nvl(v_imp_cuenta, 0);

      ELSE
         v_mto_deu_deb := nvl(v_mto_deu_deb, 0);
      END IF;
      
      --
      IF nvl(v_blo_sal_agui,'N') = 'S' THEN 
        IF v_cod_ente is not null and ((v_fecha - v_fec_aguinaldo) <= v_dia_aguinaldo) THEN
          IF nvl(pag_cta.g_ctas.sal_disponible,0) - nvl(v_tot_aguinaldo,0) > 0 THEN
            IF nvl(pag_cta.g_ctas.sal_disponible,0) - nvl(v_tot_aguinaldo,0) < (nvl(v_mto_deu_deb,0)+nvl(v_imp_cuenta,0)) THEN
              v_mto_deu_deb := nvl(pag_cta.g_ctas.sal_disponible,0) - nvl(v_tot_aguinaldo,0);
            END IF;
          ELSE
            GOTO siguiente_registro;
          END IF;
        END IF;
      END IF;
      --- Verificar si puede realizarse la operación sobre la cuenta de débito
      pag_cta.pr_ver_operacion(rel.nro_cuenta, v_cod_tra_padre, r_gmovi.cod_mod_padre,
                               r_gmovi.cod_mad_padre, 'D', pag_cta.g_ctas.cod_moneda,
                               nvl(v_mto_deu_deb, 0) + nvl(v_imp_cuenta, 0), pre.cod_oficina,
                               -- out
                               pag_cta.g_ctas.cod_modulo, pag_cta.g_ctas.cod_modalidad, v_nvo_estado,
                               v_sal_disponible, v_procesa, 503);
      IF pag_cta.g_cod_error <> 0 OR v_procesa = 'N' THEN
         /*         r_gmovi.estado    := 'E';
                  r_gmovi.cod_error := fug_obt_err_sueldos(pag_cta.g_cod_error, 'A');
                  --- Grabar movimiento con error
                  lp_ins_mov_error;
         */ --- Ir al Siguiente
        pr_ins_log_error(pre.nro_cuenta,
                pre.sal_tot_cuota,
                nvl(v_sal_disponible,0),
                'ATR 5',
                substr(pag_cta.FU_OBT_MSJ_ERROR, 1, 299)); -- 22/04/2016 GC
         GOTO siguiente_registro;
      END IF;
      --- COBRAR prestamos
      --- Convertir monto de la deuda a la del prestamo por si varió segun saldo disponible
      --- de la cuenta
      pag_gen.pr_con_mon_a_moneda(pag_cta.g_ctas.cod_moneda, pre.cod_moneda, nvl(v_mto_deu_deb, 0),
                                  v_mto_deuda, v_cot_mon_deb, v_cot_mon_pre);
      -- RI: 30/07/2010: Volver a obtener deuda para controlar que el monto a cobrar
      -- cubra por lo menos los cargos y manejar el error emergente
      pap_pre.pr_obt_deu_prestamo(pre.nro_cuenta, v_fecha, pre.nro_cuota, pre.nro_cuota,
                                  -- pre.cuo_hasta,--F.Q. debe traer solo la deuda de la cuota que trae el cursor
                                  pre.cod_oficina, v_mto_deuda, v_error, v_mensaje, v_sal_capital,
                                  v_sal_interes, v_sal_int_ade, v_mora, v_mora_interes,
                                  v_mora_int_ade, v_punitorio, v_impuesto, v_cargo, v_cargo_iva,
                                  v_int_descontado, v_dias_mora, v_cod_tra_padre);
      IF v_error <> 0 THEN
         v_rol_ejecuta := 'S';
         pr_ins_log_error(pre.nro_cuenta,
                pre.sal_tot_cuota,
                nvl(v_sal_disponible,0),
                'PRP_DEB_AUTOMATICO ATR 6',
                'Error al obtener monto a cobrar'); -- 22/04/2016 GC
         GOTO siguiente_registro;
      END IF;
      --
      v_nro_secuencia := v_nro_secuencia + 1;
      begin
          pap_pre.pr_cob_prestamo(pre.nro_cuenta, v_mto_deuda, 'N', pre.cod_oficina, pre.nro_cuota,
                                  pre.nro_cuota,
                                  -- pre.cuo_hasta, F.Q. debe cobrar solo la cuota que trae el cursor
                                  'COB. AUT. C/CTA relacionada ' || rel.nro_cuenta, v_fecha,
                                  -- in/out
                                  v_hora, v_nro_secuencia, v_cod_tra_padre, pre.cod_modulo,
                                  pre.cod_modalidad);
      exception
         when others then
            v_rol_ejecuta := 'S';
            pr_ins_log_error(pre.nro_cuenta,
                            pre.sal_tot_cuota,
                            nvl(v_sal_disponible,0),  -- OMM 26/12/2016 DYDMR-5707
                            'PRP_DEB_AUTOMATICO_ATR 7',
                            substr('Error al cobro del prestamo '||sqlerrm, 1, 299)); -- 22/04/2016 GC
            GOTO siguiente_registro;
      end;
      -- se vuelve a obtener los datos de la cuenta de debito, porque pudo haber cambiado en el pap_pre (x garantias cash)
      pag_cta.pr_obt_cuenta(rel.nro_cuenta);
      --calcula impuesto si corresponde y genera movimiento, en moneda de cta débito
      BEGIN
         prg_ver_cob_cargos(rel.nro_cuenta, pre.nro_cuenta, pre.cod_modulo, pre.cod_modalidad,
                            pre.cod_oficina,
                            --oficina del préstamo, oficina origen
                            pag_cta.g_ctas.cod_moneda, v_mto_deu_deb,
                            'Cobro aut. Préstamo Moroso ' || pre.nro_cuenta, NULL,
                            --v_nro_documento,
                            v_fecha, v_hora, v_imp_cuenta, v_nro_secuencia, 'S');
      EXCEPTION
         WHEN OTHERS THEN
            v_imp_cuenta := 0; --para que no caiga
      END;
      --- DEBITAR de la cuenta
      v_nro_secuencia := v_nro_secuencia + 1;

      v_con_debito := 'COBRO AUT. PRESTAMO MOROSO' || pre.nro_cuenta;
      pag_cta.pr_act_operacion(rel.nro_cuenta, v_hora, 'D', pag_cta.g_ctas.cod_moneda,
                               nvl(v_mto_deu_deb, 0) + nvl(v_imp_cuenta, 0), v_cod_tra_padre, 503,
                               pre.nro_documento, NULL, pre.cod_oficina, pre.cod_modulo,
                               pre.cod_modalidad, NULL, NULL,
                               v_con_debito, 'S', v_nro_secuencia
                               /* in/out */, v_fecha);
      if pag_cta.fu_obt_cod_error <> 0 then
          v_rol_ejecuta := 'S';
          pr_ins_log_error(pre.nro_cuenta,
                pre.sal_tot_cuota,
                nvl(v_sal_disponible,0),
                'PRP_DEB_AUTOMATICO_ATR 8',
                substr(pag_cta.FU_OBT_MSJ_ERROR, 1, 299)); -- 22/04/2016 GC
          GOTO siguiente_registro;
      end if;

      BEGIN
         pr_ver_mov_debito;
       EXCEPTION
         WHEN OTHERS THEN
            v_rol_ejecuta := 'S';
            pr_ins_log_error(pre.nro_cuenta,
                            pre.sal_tot_cuota,
                            0,
                            'PRP_DEB_AUTOMATICO_ATR 9',
                            substr('Error en pr_ver_mov_debito '||sqlerrm,1,299)); -- 22/04/2016 GC
            GOTO siguiente_registro;
      END;

      /*-----------------------------------------------------------------
      -- obtiene la cotizacion de la moneda si la moneda no es local --
      -----------------------------------------------------------------
      IF pre.cod_moneda <> v_cod_mon_local THEN
         IF pag_cta.g_ctas.cod_moneda = v_cod_mon_local THEN --  es una venta
             OBTENER_COTIZACION('V',:ABMC.SCR_CDMONED,:CABECERA.WFECHA,
                                    :ABMC.SCR_COTIZAC);
         ELSE -- es la cotizacion de cierre
             OBTENER_COTIZACION('X',:ABMC.SCR_CDMONED,:CABECERA.WFECHA,
                                    :ABMC.SCR_COTIZAC);
         END IF;
      ELSE
         :ABMC.SCR_COTIZAC := NULL;
      END IF;
         IF r_gmovi.estado = 'N' AND pag_cta.g_ctas.cod_moneda <> pre.cod_moneda THEN
            -- realizo la operacion de cambios si es necesario
            IF pag_cta.g_ctas.cod_moneda = v_cod_mon_local THEN
               --- ventad de divisas
               VENTA_DE_DIVISAS(:ABMC.SCR_CDMONED,
                                 NVL(:WK_INTERES,0)+NVL(:WK_CAPITAL,0)+
                                 NVL(:WK_SLINTAD,0) +
                                 NVL(:SCR_MORA_INT,0)+NVL(:SCR_MORA,0)+
                                 NVL(:SCR_MORA_ADE,0)+NVL(:SCR_CARGO,0),
                     ROUND(NVL(:WK_DEBITO,0)-NVL(:SCR_IMPUESTO_GS,0)));
            ELSIF pre.cod_moneda = v_cod_mon_local THEN
               --- compra de divisas
               COMPRA_DE_DIVISAS(:WK_MONEDEB,:WK_DEBITO,
                                 NVL(:WK_INTERES,0)+NVL(:WK_CAPITAL,0)+
                                 NVL(:SCR_IMPUESTO,0)+NVL(:WK_SLINTAD,0) +
                                 NVL(:SCR_MORA_INT,0)+NVL(:SCR_MORA,0)+
                                 NVL(:SCR_MORA_ADE,0)+NVL(:SCR_CARGO,0));
            ELSE
               MESSAGE('Operacion de Arbitraje no se permite ');
               RAISE FORM_TRIGGER_FAILURE;
            END IF;
         END IF;  */ -- OJO se implementa con Cambios
      v_commitea := 'S';
      --- Siguiente registro
      <<siguiente_registro>>
      -- se controla si se realizará rollback y se prende control para evitar intentos de otras cuotas
      -- del mismo prestamo si este no fue cobrado.
      IF v_rol_ejecuta = 'S' then
         prg_rol_savepoint(v_rol_referencia);
         v_sig_prestamo := 'S';
      ELSIF v_commitea = 'S' THEN
--         commit;
           v_commitea := 'S';
      END IF;
    END LOOP;
   END LOOP;
End;
/
