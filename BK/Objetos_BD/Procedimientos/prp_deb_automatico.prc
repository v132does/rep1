CREATE OR REPLACE PROCEDURE IT.PRP_DEB_AUTOMATICO
(
   p_cod_persona IN VARCHAR2 DEFAULT NULL,
   p_nro_cuenta  IN VARCHAR2 DEFAULT NULL,
   p_pag_parcial IN VARCHAR2 DEFAULT NULL,
   p_cta_debito  IN VARCHAR2 DEFAULT NULL
) IS

   -- variables para rollback
   v_rol_referencia varchar2(30) := 'inicio';
   v_rol_ejecuta    varchar2(1) := 'N';
   v_commitea       varchar2(1) := 'N';
   v_sig_prestamo   varchar2(1) := 'N'; -- tambien se usa para pasar a siguiente prestamo si el saldo es 0
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
   v_pag_parcial  VARCHAR2(01);
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
   v_min_cob_aut    NUMBER(18,2);
   --- Datos para utilizar la cuenta de débito
   v_mto_deu_deb    ge_cuentas.sal_contable%TYPE;
   v_cot_mon_pre    ge_cotizaciones.val_conversion%TYPE;
   v_cot_mon_deb    ge_cotizaciones.val_conversion%TYPE;
   v_nvo_estado     ge_cuentas.estado%TYPE;
   v_sal_disponible ge_cuentas.sal_contable%TYPE;
   v_procesa        VARCHAR2(01);
   v_error          VARCHAR2(10);
   v_mensaje        VARCHAR2(1000);
   v_imp_cuenta     pr_cuotas.sal_interes%TYPE:=0;
   v_con_debito     ge_movimientos.concepto%type;
   v_cod_causa     ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('GEN_COD_CAU_INH_COBRO');
   v_cod_tra_aguinaldo ge_transacciones.cod_transaccion%type;
   v_tot_aguinaldo  number := 0;
   v_fec_ini_mes    date;
   v_cod_ente       ah_cta_vistas.cod_ente%type := null;
   v_dia_aguinaldo  ge_par_dinamicos.val_parametro%type;
   v_fec_aguinaldo  date;
   v_blo_sal_agui   varchar2(1) := nvl(fug_obt_pardinamico('BLO_DEB_SAL_AGUINALDO'),'N');  
   --RI: 15/12/2010: Parametro creado para determinar si se procesa cuenta de nomina
   --v_pro_cta_nomina varchar2(1) := nvl(fug_obt_pardinamico('PRO_CTA_NOMINA'),'S'); COMENTADO PORQUE NO ESTÁ IMPLEMENTADO AÚN EL REQUERIMIENTO A PEDIDO DE VCAPRA EL 04/03/2011
   --- Cursor de cuentas de préstamos con débito automático

   --- Toma todas las cuotas atrasadas de todos los préstamos hasta la fecha actual, y además ordena por
   --- la fecha de vencimiento y el saldo de la cuota para el débito
   --- Procedimiento Modificado para Optimización AP 3006
   CURSOR c_debitos IS
      SELECT pr.nro_cuenta,
             cl.cod_persona,
             pr.nro_cta_debito,
             pr.cod_oficina,
             cu.nro_cuota,
             pr.cod_moneda,
             pr.cod_modulo,
             pr.cod_modalidad,
             cu.nro_documento,
             cuo.cuo_hasta,
             (NVL(cu.sal_capital, 0) + NVL(cu.sal_interes, 0) +
             NVL(cu.sal_int_documentado, 0)) sal_tot_cuota,
             cu.fec_vencimiento
        FROM pr_cuotas cu,
             (select max(nro_cuota) cuo_hasta, nro_cuenta
                from pr_cuotas
               where fec_vencimiento <= v_fecha
                 and estado <> 'N'
                 and nvl(sal_capital, 0) + nvl(sal_interes, 0) +
                     nvl(sal_int_documentado, 0) > 0
               group by nro_cuenta) cuo,
             pr_cta_prestamos pr,
             ge_cta_clientes cl
       WHERE pr.nro_cuenta = cu.nro_cuenta
         AND pr.nro_cuenta = cl.nro_cuenta
         AND cuo.nro_cuenta = pr.nro_cuenta
         AND pr.cod_modalidad NOT IN (608) --- no incluir asociaciones ni descuentos documentos
         AND NVL(fug_obt_pardinamico('MAD_ANTICIPOS',
                                     pr.cod_modulo,
                                     pr.cod_modalidad),
                 'N') = 'N' --No debe incluir Anticipos al Personal
         AND cl.relacion = 'P' --- Cliente principal
         AND pr.estado <> 'N' --- Préstamos no cancelados
         AND pr.nro_cta_debito is not null
         AND pr.cob_automatico = 'S'
         AND cu.fec_vencimiento <= v_fecha
         AND cu.nro_cuota > 0
         AND cu.estado <> 'N'
         AND nvl(fug_obt_paradicional(pr.nro_cuenta,
                                      'EXC_CTA_COB_AUTOMATICO'),
                 'N') <> 'S'
         AND NOT EXISTS
       (SELECT 1
                FROM GE_PER_INHIBIDAS A
                JOIN GE_CAUSALES B
                  ON A.COD_CAUSA = B.COD_CAUSA
               WHERE A.ESTADO = 'I'
                 AND A.COD_PERSONA = CL.COD_PERSONA
                 AND INSTR(v_cod_causa, A.COD_CAUSA) > 0
              UNION ALL
              SELECT 1
                FROM GE_CUENTAS A
                JOIN GE_CTA_CLIENTES B
                  ON A.NRO_CUENTA = B.NRO_CUENTA
                JOIN GE_PER_INHIBIDAS C
                  ON B.COD_PERSONA = C.COD_PERSONA
               WHERE C.ESTADO = 'I'
                 AND B.RELACION <> 'P'
                 AND INSTR(v_cod_causa, C.COD_CAUSA) > 0
                 AND B.NRO_CUENTA = PR.NRO_CUENTA
                 AND ROWNUM = 1)
         AND (p_nro_cuenta  IS NULL OR pr.nro_cuenta = p_nro_cuenta)
         AND (p_cod_persona IS NULL OR cl.cod_persona = p_cod_persona)
         AND (p_cta_debito  IS NULL OR pr.nro_cta_debito = p_cta_debito)
       ORDER BY cu.fec_vencimiento asc;

    -- Type de tipo record para collect 
    TYPE typ_pr_cuotas_deb IS RECORD (
       nro_cuenta      it.pr_cta_prestamos.nro_cuenta%type,
       cod_persona     it.ge_cta_clientes.cod_persona%type,
       nro_cta_debito  it.pr_cta_prestamos.nro_cta_debito%type,
       cod_oficina     it.pr_cta_prestamos.cod_oficina%type,
       nro_cuota       it.pr_cuotas.nro_cuota%type,
       cod_moneda      it.pr_cta_prestamos.cod_moneda%type, 
       cod_modulo      it.pr_cta_prestamos.cod_modulo%type,
       cod_modalidad   it.pr_cta_prestamos.cod_modalidad%type,
       nro_documento   it.pr_cuotas.nro_documento%type,
       cuo_hasta       it.pr_cuotas.nro_cuota%type,
       sal_tot_cuota   it.pr_cuotas.sal_capital%type,
       fec_vencimiento it.pr_cuotas.fec_vencimiento%type
   );
  
   -- Declaracion del type para nominas para prestamos
   TYPE t_pr_cuo_debito IS TABLE OF typ_pr_cuotas_deb;
   l_deb_pr_cuota       t_pr_cuo_debito;   
  
   -- Creacion del type record   
   TYPE typ_tm_log_nominas IS RECORD (
     nro_cuenta   tm_log_nominas.nro_cuenta%TYPE,
     monto        tm_log_nominas.monto%TYPE,
     sal_total    tm_log_nominas.sal_total%TYPE,
     lugar        tm_log_nominas.lugar%TYPE,
     observacion  tm_log_nominas.observacion%TYPE
   );
  
   -- Declaracion del type para nominas
   TYPE t_tm_log_nominas IS TABLE OF typ_tm_log_nominas INDEX BY PLS_INTEGER;
   v_tm_log_nominas t_tm_log_nominas;  
   v_id PLS_INTEGER := 0;
   
   TYPE t_log_clave IS TABLE OF BOOLEAN INDEX BY VARCHAR2(4000);
   v_log_clave t_log_clave;
   v_clave     VARCHAR2(4000);
     
   /* Inserta movimiento con error. */
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
   
   PROCEDURE lp_obt_mto_aguinaldo( p_nro_cta       IN  VARCHAR2,
                                   p_mto_aguinaldo OUT NUMBER,
                                   p_fec_aguinaldo OUT DATE) IS
    BEGIN
      select sum(a.monto), max(a.fecha)
        into p_mto_aguinaldo, p_fec_aguinaldo
        from gv_movimientos a
       where a.fecha >= v_fec_ini_mes
         and a.fecha <= v_fecha
         and a.cod_tra_padre = v_cod_tra_aguinaldo
         and a.cod_transaccion = 602
         and a.nro_cuenta = p_nro_cta
         and a.reversado = 'N';
         
    exception
      when others then
        p_mto_aguinaldo :=0; 
        p_fec_aguinaldo :=null;
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
   PROCEDURE pr_ins_log_error(p_reg_log IN t_tm_log_nominas) IS
    BEGIN
     FORALL l IN p_reg_log.FIRST .. p_reg_log.LAST
      insert into tm_log_nominas
      (nro_cuenta, monto, sal_total, lugar, observacion, fec_insercion)
      values
      (p_reg_log(l).nro_cuenta, p_reg_log(l).monto, p_reg_log(l).sal_total, p_reg_log(l).lugar, p_reg_log(l).observacion, sysdate);
    END ;

BEGIN
   --Recuperar datos de fecha calendario
   v_cod_modulo := 6;
   v_fecha      := pag_cal.fu_obt_fec_actual(v_cod_modulo);
   --RI: 18/10/2010: Si no se ejecuta desde el cierre tomar la hora actual
   v_hora := to_char(SYSDATE, 'HH24:MI:SS');
   v_hora := fug_obt_hor_disponible(v_fecha,v_hora,user,'N');
   v_nro_secuencia  := 0;
   v_cod_tra_padre  := 364;
   v_cod_mon_local  := pag_gen.fu_obt_mon_local;
   v_nro_cuenta_ant := 'x';
   v_sig_prestamo   := 'N';
   v_dia_aguinaldo  := nvl(fug_obt_pardinamico('CAN_DIA_DEB_AGUINALDO'),0);
   pag_cal.PR_OBT_DAT_CALENDAR(1);
   v_fec_ini_mes    := pag_cal.G_PRI_DIA_MES;  
  
   OPEN c_debitos;
   LOOP
     FETCH c_debitos BULK COLLECT INTO l_deb_pr_cuota LIMIT 100000;
   EXIT WHEN l_deb_pr_cuota.COUNT = 0; 
          
   FOR i IN 1 .. l_deb_pr_cuota.COUNT LOOP

      -- Control de rollback
      v_rol_referencia := l_deb_pr_cuota(i).nro_cuenta||l_deb_pr_cuota(i).nro_cuota;
      prg_cre_savepoint(v_rol_referencia);
      v_rol_ejecuta    := 'N';
      v_commitea       := 'N';

      --- Inicializar variables auxiliares
      r_gmovi          := NULL;
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
      v_cot_mon_pre    := NULL;
      v_cot_mon_deb    := NULL;   

      IF l_deb_pr_cuota(i).nro_cuenta <> v_nro_cuenta_ant THEN
         --- Para grabar por cada registro procesado y sus movimientos la misma hora
         v_hora := fug_obt_hor_disponible(v_fecha,v_hora,user,'N');
         v_nro_secuencia  := 0;
         v_nro_cuenta_ant := l_deb_pr_cuota(i).nro_cuenta;
         v_sig_prestamo   := 'N';
         v_cod_ente       := null;
         v_min_cob_aut    := fug_obt_pardinamico('MIN_COB_AUT', l_deb_pr_cuota(i).cod_modulo, l_deb_pr_cuota(i).cod_modalidad, 
                             l_deb_pr_cuota(i).cod_moneda, l_deb_pr_cuota(i).cod_oficina);
      ELSE
         -- Prestamo es igual al anterior, continua solo si hubo commit(sino esta prendido v_sig_prestamo)
         IF v_sig_prestamo = 'S' then
            GOTO siguiente_registro;
         END IF;
      END IF;

      --- Inicializar registro de movimiento por si da error
      r_gmovi.cod_ofi_origen := l_deb_pr_cuota(i).cod_oficina;
      r_gmovi.cod_mod_padre  := l_deb_pr_cuota(i).cod_modulo;
      r_gmovi.cod_mad_padre  := l_deb_pr_cuota(i).cod_modalidad;
      r_gmovi.nro_documento  := l_deb_pr_cuota(i).nro_documento;
      r_gmovi.concepto       := 'Prest.' || l_deb_pr_cuota(i).nro_cuenta;

      -- movido esta seccion mas arriba, ya que hay muchas cuentas de debito sin saldo de tal forma a
      -- optimizar el tiempo de procesamiento de prestamos que no tienen saldo minimo para el cobro

      --- Recuperar datos de la cuenta de ahorro
      pag_cta.pr_obt_cuenta(l_deb_pr_cuota(i).nro_cta_debito);
      r_gmovi.cod_modulo      := pag_cta.g_ctas.cod_modulo;
      r_gmovi.cod_modalidad   := pag_cta.g_ctas.cod_modalidad;
      r_gmovi.nro_cuenta      := l_deb_pr_cuota(i).nro_cta_debito;
      r_gmovi.cod_moneda      := pag_cta.g_ctas.cod_moneda;
      r_gmovi.cod_transaccion := 503;
      v_cod_ente              := pag_cta.g_ctas.cod_ente;
      IF pag_cta.g_cod_error <> 0 THEN
        v_id := v_id + 1;
        v_tm_log_nominas(v_id).nro_cuenta :=l_deb_pr_cuota(i).nro_cuenta;
        v_tm_log_nominas(v_id).monto      :=l_deb_pr_cuota(i).sal_tot_cuota;
        v_tm_log_nominas(v_id).sal_total  :=0;
        v_tm_log_nominas(v_id).lugar      :='PRP_DEB_AUTOMATICO';
        v_tm_log_nominas(v_id).observacion:=substr(pag_cta.FU_OBT_MSJ_ERROR, 1, 299);
        GOTO siguiente_registro;
      END IF;
      
      IF nvl(pag_cta.g_ctas.sal_disponible, 0) + nvl(pag_cta.g_ctas.sal_dis_combinada, 0) <= 0 THEN
         v_clave := l_deb_pr_cuota(i).nro_cuenta;
       IF NOT v_log_clave.exists(v_clave) THEN
          v_id := v_id + 1;
          v_tm_log_nominas(v_id).nro_cuenta :=l_deb_pr_cuota(i).nro_cuenta;
          v_tm_log_nominas(v_id).monto      :=l_deb_pr_cuota(i).sal_tot_cuota;
          v_tm_log_nominas(v_id).sal_total  :=nvl(pag_cta.g_ctas.sal_disponible, 0) + nvl(pag_cta.g_ctas.sal_dis_combinada, 0);
          v_tm_log_nominas(v_id).lugar      :='PRP_DEB_AUTOMATICO 1';
          v_tm_log_nominas(v_id).observacion:='Cuenta sin saldo para el debito';
          v_log_clave(v_clave) := TRUE;
       END IF;   
         v_sig_prestamo := 'S'; -- se registra cta en el log y se pasa al ste prestamo  
        GOTO siguiente_registro;  
      END IF;
      
      --- Verificar monedas ----
      IF pag_cta.g_ctas.cod_moneda <> l_deb_pr_cuota(i).cod_moneda AND -- Cta. Débito Vs Préstamo
         pag_cta.g_ctas.cod_moneda <> v_cod_mon_local AND              -- Cta. Débito Vs Local
         l_deb_pr_cuota(i).cod_moneda <> v_cod_mon_local THEN
         GOTO siguiente_registro;
      END IF;
      --- Calculo el total a debitar en la moneda de la cuenta de debito
      IF pag_cta.g_ctas.cod_moneda <> l_deb_pr_cuota(i).cod_moneda then
         pag_gen.pr_con_mon_a_moneda(l_deb_pr_cuota(i).cod_moneda, pag_cta.g_ctas.cod_moneda, l_deb_pr_cuota(i).sal_tot_cuota,
                                     v_mto_deu_deb, v_cot_mon_pre, v_cot_mon_deb);
      ELSE
         v_mto_deu_deb := l_deb_pr_cuota(i).sal_tot_cuota;                            
      END IF;  
      
      --- Verificar parámetro de pago para identificar el monto de la deuda
      IF p_pag_parcial IS NULL THEN
         v_pag_parcial := fug_obt_pardinamico('PAG_COB_AUT', l_deb_pr_cuota(i).cod_modulo, l_deb_pr_cuota(i).cod_modalidad,
                                              l_deb_pr_cuota(i).cod_moneda, l_deb_pr_cuota(i).cod_oficina);
      ELSE
         v_pag_parcial := p_pag_parcial;
      END IF;
      --SDPARDEBAU-2-HO: No se debe tener en cuenta la linea de sobregiro, esta prohibido por el ente regulador. No se puede pagar un producto crediticio como el prestamo con otro, que es el sobregiro
      IF (v_pag_parcial = 'N' AND
         nvl(pag_cta.g_ctas.sal_disponible, 0) + nvl(pag_cta.g_ctas.sal_dis_combinada, 0) 
         < nvl(v_mto_deu_deb, 0)) OR
         (v_pag_parcial = 'S' AND
         (nvl(pag_cta.g_ctas.sal_disponible, 0) + nvl(pag_cta.g_ctas.sal_dis_combinada, 0) 
         <= 0 OR
         nvl(pag_cta.g_ctas.sal_disponible, 0) + nvl(pag_cta.g_ctas.sal_dis_combinada, 0) 
         < v_min_cob_aut )) THEN
          v_id := v_id + 1;
          v_tm_log_nominas(v_id).nro_cuenta :=l_deb_pr_cuota(i).nro_cuenta;
          v_tm_log_nominas(v_id).monto      :=l_deb_pr_cuota(i).sal_tot_cuota;
          v_tm_log_nominas(v_id).sal_total  :=nvl(pag_cta.g_ctas.sal_disponible, 0) + nvl(pag_cta.g_ctas.sal_dis_combinada, 0);
          v_tm_log_nominas(v_id).lugar      :='PRP_DEB_AUTOMATICO 2';
          v_tm_log_nominas(v_id).observacion:='Saldo no cubre totalidad de la deuda';
          v_sig_prestamo := 'S'; -- se registra cta en el log y se pasa al ste prestamo                
          -- Solo se cobra si el saldo de la cuenta cubre toda la deuda
          GOTO siguiente_registro;
      END IF;
      
        IF nvl(v_blo_sal_agui,'N') = 'S' THEN
          if v_cod_ente is not null then
             v_cod_tra_aguinaldo := fug_obt_parentes(v_cod_ente, 'COD_TRA_PAD_AGUINALDO');
             if v_cod_tra_aguinaldo is not null then 
              lp_obt_mto_aguinaldo(l_deb_pr_cuota(i).nro_cta_debito, v_tot_aguinaldo, v_fec_aguinaldo);
             end if;
          end if;  
        END IF;
      --- Agregado hasta aqui para un control previo...
      --- Recuperar deuda a la fecha del proceso
      --- Recuperar deuda de la cuota
      pap_pre.pr_obt_deu_prestamo(l_deb_pr_cuota(i).nro_cuenta, v_fecha, l_deb_pr_cuota(i).nro_cuota, l_deb_pr_cuota(i).nro_cuota,
                                  -- pre.cuo_hasta, F.Q. debe traer solo la deuda de la cuota que trae el cursor
                                  l_deb_pr_cuota(i).cod_oficina, null, v_error, v_mensaje, v_sal_capital,
                                  v_sal_interes, v_sal_int_ade, v_mora, v_mora_interes,
                                  v_mora_int_ade, v_punitorio, v_impuesto, v_cargo, v_cargo_iva,
                                  v_int_descontado, v_dias_mora, v_cod_tra_padre);
      IF v_error <> 0 THEN
         ---NO GENERAR MOV CON ERROR XQ DA PROBLEMAS EN ASIENTOS
         ---raise_application_error(-20000, v_mensaje); OJO por ahora error ver + adelante
         ---Ir al Siguiente
         v_rol_ejecuta := 'S';
         v_id := v_id + 1;
         v_tm_log_nominas(v_id).nro_cuenta :=l_deb_pr_cuota(i).nro_cuenta;
         v_tm_log_nominas(v_id).monto      :=l_deb_pr_cuota(i).sal_tot_cuota;
         v_tm_log_nominas(v_id).sal_total  :=0;
         v_tm_log_nominas(v_id).lugar      :='PRP_DEB_AUTOMATICO 3';
         v_tm_log_nominas(v_id).observacion:=SUBSTR('Error al recuperar deuda del prestamo '||v_mensaje, 1, 299);
         GOTO siguiente_registro;
      END IF;
      v_mto_deuda := nvl(v_sal_capital, 0) + nvl(v_sal_interes, 0) + nvl(v_sal_int_ade, 0) +
                     nvl(v_mora, 0) + nvl(v_mora_interes, 0) + nvl(v_mora_int_ade, 0) +
                     nvl(v_punitorio, 0) + nvl(v_impuesto, 0) + nvl(v_cargo, 0);
      --- Calculo el total a debitar en la moneda de la cuenta de debito
     IF pag_cta.g_ctas.cod_moneda <> l_deb_pr_cuota(i).cod_moneda then 
       pag_gen.pr_con_mon_a_moneda(l_deb_pr_cuota(i).cod_moneda, pag_cta.g_ctas.cod_moneda, v_mto_deuda,
                                   v_mto_deu_deb, v_cot_mon_pre, v_cot_mon_deb);
     ELSE
       v_mto_deu_deb := v_mto_deuda;
     END IF; 
      IF (v_pag_parcial = 'N' AND
         nvl(pag_cta.g_ctas.sal_disponible, 0) + nvl(pag_cta.g_ctas.sal_dis_combinada, 0) < nvl(v_mto_deu_deb, 0)) OR
         (v_pag_parcial = 'S' AND (nvl(pag_cta.g_ctas.sal_disponible, 0) + nvl(pag_cta.g_ctas.sal_dis_combinada, 0) 
         <= 0 OR nvl(pag_cta.g_ctas.sal_disponible, 0) + nvl(pag_cta.g_ctas.sal_dis_combinada, 0) 
         < v_min_cob_aut)) THEN
         v_id := v_id + 1;
         v_tm_log_nominas(v_id).nro_cuenta :=l_deb_pr_cuota(i).nro_cuenta;
         v_tm_log_nominas(v_id).monto      :=l_deb_pr_cuota(i).sal_tot_cuota;
         v_tm_log_nominas(v_id).sal_total  :=nvl(pag_cta.g_ctas.sal_disponible, 0) + nvl(pag_cta.g_ctas.sal_dis_combinada, 0);
         v_tm_log_nominas(v_id).lugar      :='PRP_DEB_AUTOMATICO 4';
         v_tm_log_nominas(v_id).observacion:='Saldo no cubre totalidad de la deuda';  
         -- Solo se cobra si el saldo de la cuenta cubre toda la deuda
         GOTO siguiente_registro;
      END IF;

      IF v_pag_parcial = 'S' AND
         (nvl(pag_cta.g_ctas.sal_disponible, 0) + nvl(pag_cta.g_ctas.sal_dis_combinada, 0)) 
         < nvl(v_mto_deu_deb, 0) + nvl(v_imp_cuenta, 0) THEN
         v_imp_cuenta := (nvl(pag_cta.g_ctas.sal_disponible, 0) +
                         nvl(pag_cta.g_ctas.sal_dis_combinada, 0) ) /
                         nvl(v_mto_deu_deb, 0) * nvl(v_imp_cuenta, 0);
         IF l_deb_pr_cuota(i).cod_moneda = pag_gen.fu_obt_mon_local THEN
            v_imp_cuenta := ceil(v_imp_cuenta);
         END IF;
         v_mto_deu_deb := (nvl(pag_cta.g_ctas.sal_disponible, 0) +
                          nvl(pag_cta.g_ctas.sal_dis_combinada, 0) ) -
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
      pag_cta.pr_ver_operacion(l_deb_pr_cuota(i).nro_cta_debito, v_cod_tra_padre, r_gmovi.cod_mod_padre,
                               r_gmovi.cod_mad_padre, 'D', pag_cta.g_ctas.cod_moneda,
                               nvl(v_mto_deu_deb, 0) + nvl(v_imp_cuenta, 0), l_deb_pr_cuota(i).cod_oficina,
                               -- out
                               pag_cta.g_ctas.cod_modulo, pag_cta.g_ctas.cod_modalidad, v_nvo_estado,
                               v_sal_disponible, v_procesa, 503);
      IF pag_cta.g_cod_error <> 0 OR v_procesa = 'N' THEN
        --- Ir al Siguiente
        v_id := v_id + 1;
        v_tm_log_nominas(v_id).nro_cuenta :=l_deb_pr_cuota(i).nro_cuenta;
        v_tm_log_nominas(v_id).monto      :=l_deb_pr_cuota(i).sal_tot_cuota;
        v_tm_log_nominas(v_id).sal_total  :=nvl(v_sal_disponible,0);
        v_tm_log_nominas(v_id).lugar      :='PRP_DEB_AUTOMATICO 5';
        v_tm_log_nominas(v_id).observacion:=substr(pag_cta.FU_OBT_MSJ_ERROR, 1, 299);
        GOTO siguiente_registro;
      END IF;
      --- COBRAR prestamos
      --- Convertir monto de la deuda a la del prestamo por si varió segun saldo disponible
      --- de la cuenta
      IF pag_cta.g_ctas.cod_moneda <> l_deb_pr_cuota(i).cod_moneda then
        pag_gen.pr_con_mon_a_moneda(pag_cta.g_ctas.cod_moneda, l_deb_pr_cuota(i).cod_moneda, nvl(v_mto_deu_deb, 0),
                                    v_mto_deuda, v_cot_mon_deb, v_cot_mon_pre);
      ELSE
        v_mto_deuda := nvl(v_mto_deu_deb, 0);
      END IF;                              
      -- RI: 30/07/2010: Volver a obtener deuda para controlar que el monto a cobrar
      -- cubra por lo menos los cargos y manejar el error emergente
      pap_pre.pr_obt_deu_prestamo(l_deb_pr_cuota(i).nro_cuenta, v_fecha, l_deb_pr_cuota(i).nro_cuota, l_deb_pr_cuota(i).nro_cuota,
                                  -- pre.cuo_hasta,--F.Q. debe traer solo la deuda de la cuota que trae el cursor
                                  l_deb_pr_cuota(i).cod_oficina, v_mto_deuda, v_error, v_mensaje, v_sal_capital,
                                  v_sal_interes, v_sal_int_ade, v_mora, v_mora_interes,
                                  v_mora_int_ade, v_punitorio, v_impuesto, v_cargo, v_cargo_iva,
                                  v_int_descontado, v_dias_mora, v_cod_tra_padre);
      IF v_error <> 0 THEN
        v_rol_ejecuta := 'S';
        v_id := v_id + 1;
        v_tm_log_nominas(v_id).nro_cuenta :=l_deb_pr_cuota(i).nro_cuenta;
        v_tm_log_nominas(v_id).monto      :=l_deb_pr_cuota(i).sal_tot_cuota;
        v_tm_log_nominas(v_id).sal_total  :=nvl(v_sal_disponible,0);
        v_tm_log_nominas(v_id).lugar      :='PRP_DEB_AUTOMATICO 6';
        v_tm_log_nominas(v_id).observacion:=SUBSTR('Error al obtener monto a cobrar '||v_mensaje, 1, 299);
        GOTO siguiente_registro;
      END IF;
      --
      v_nro_secuencia := v_nro_secuencia + 1;
      begin
          pap_pre.pr_cob_prestamo(l_deb_pr_cuota(i).nro_cuenta, v_mto_deuda, 'N', l_deb_pr_cuota(i).cod_oficina, l_deb_pr_cuota(i).nro_cuota,
                                  l_deb_pr_cuota(i).nro_cuota,
                                  -- pre.cuo_hasta, F.Q. debe cobrar solo la cuota que trae el cursor
                                  'COB. AUT. C/CTA ' || l_deb_pr_cuota(i).nro_cta_debito, v_fecha,
                                  -- in/out
                                  v_hora, v_nro_secuencia, v_cod_tra_padre, l_deb_pr_cuota(i).cod_modulo,
                                  l_deb_pr_cuota(i).cod_modalidad);
      exception
         when others then
            v_rol_ejecuta := 'S';
            v_id := v_id + 1;
            v_tm_log_nominas(v_id).nro_cuenta :=l_deb_pr_cuota(i).nro_cuenta;
            v_tm_log_nominas(v_id).monto      :=l_deb_pr_cuota(i).sal_tot_cuota;
            v_tm_log_nominas(v_id).sal_total  :=nvl(v_sal_disponible,0);
            v_tm_log_nominas(v_id).lugar      :='PRP_DEB_AUTOMATICO 7';
            v_tm_log_nominas(v_id).observacion:=substr('Error al cobro del prestamo'||sqlerrm, 1, 299);
            GOTO siguiente_registro;
      end;
      -- se vuelve a obtener los datos de la cuenta de debito, porque pudo haber cambiado en el pap_pre (x garantias cash)
      pag_cta.pr_obt_cuenta(l_deb_pr_cuota(i).nro_cta_debito);
      --- DEBITAR de la cuenta
      v_nro_secuencia := v_nro_secuencia + 1;
      v_con_debito := 'COBRO AUT. PRESTAMO ' || l_deb_pr_cuota(i).nro_cuenta;
      pag_cta.pr_act_operacion(l_deb_pr_cuota(i).nro_cta_debito, v_hora, 'D', pag_cta.g_ctas.cod_moneda,
                               nvl(v_mto_deu_deb, 0) + nvl(v_imp_cuenta, 0), v_cod_tra_padre, 503,
                               l_deb_pr_cuota(i).nro_documento, NULL, l_deb_pr_cuota(i).cod_oficina, l_deb_pr_cuota(i).cod_modulo,
                               l_deb_pr_cuota(i).cod_modalidad, NULL, NULL,
                               v_con_debito, 'S', v_nro_secuencia
                               /* in/out */, v_fecha);
      if pag_cta.fu_obt_cod_error <> 0 then
         v_rol_ejecuta := 'S';
         v_id := v_id + 1;
         v_tm_log_nominas(v_id).nro_cuenta :=l_deb_pr_cuota(i).nro_cuenta;
         v_tm_log_nominas(v_id).monto      :=l_deb_pr_cuota(i).sal_tot_cuota;
         v_tm_log_nominas(v_id).sal_total  :=nvl(v_sal_disponible,0);
         v_tm_log_nominas(v_id).lugar      :='PRP_DEB_AUTOMATICO 8';
         v_tm_log_nominas(v_id).observacion:=substr(pag_cta.FU_OBT_MSJ_ERROR, 1, 299);
         GOTO siguiente_registro;
      end if;

      BEGIN
         pr_ver_mov_debito;
       EXCEPTION
         WHEN OTHERS THEN
            v_rol_ejecuta := 'S';
            v_id := v_id + 1;
            v_tm_log_nominas(v_id).nro_cuenta :=l_deb_pr_cuota(i).nro_cuenta;
            v_tm_log_nominas(v_id).monto      :=l_deb_pr_cuota(i).sal_tot_cuota;
            v_tm_log_nominas(v_id).sal_total  :=0;
            v_tm_log_nominas(v_id).lugar      :='PRP_DEB_AUTOMATICO 9';
            v_tm_log_nominas(v_id).observacion:=substr('Error en pr_ver_mov_debito'||sqlerrm,1,299);
            GOTO siguiente_registro;
      END;
      --- OJO se implementa con Cambios
      v_commitea := 'S';
      --- Siguiente registro
      <<siguiente_registro>>
      -- se controla si se realizará rollback y se prende control para evitar intentos de otras cuotas
      -- del mismo prestamo si este no fue cobrado.
      IF v_rol_ejecuta = 'S' then
         prg_rol_savepoint(v_rol_referencia);
         v_sig_prestamo := 'S';
      ELSIF v_commitea = 'S' THEN
        commit;
      END IF;
      /* PCCDEEVO-1046: SE AGREGA LLAMADA AL PROCESO NUEVO PARA DEBITAR DE LAS CUENTAS RELACIONADAS COMO PRINCIPAL
         O INDEPENDIENTE A LOS TITULARES DE LAS CUENTAS QUE NO SE PUDIERON DEBITAR POR EL PROCESO NORMAL EL DIA ANTERIOR.*/
     END LOOP;
    l_deb_pr_cuota := t_pr_cuo_debito();
  END LOOP;
   -- procesamos el log 
   pr_ins_log_error(v_tm_log_nominas);
   commit; -- Confirmar los cambios para el log

  if nvl(fug_obt_pardinamico('PRE_COB_AUT_ATR_PRESTAMOS'), 'N') = 'S' then
     if nvl(fug_obt_pardinamico('GEN_COB_AUT_CRE_SALARIOS'), 'N') = 'S' or
       (nvl(fug_obt_pardinamico('GEN_COB_AUT_CRE_SALARIOS'), 'N') = 'N' AND
       nvl(pae_cnf.g_programa, 'X') <> 'GPPAGSUE') then
       PRP_DEB_AUTOMATICO_ATR(p_cod_persona, p_nro_cuenta, p_cta_debito);
     end if;
  end if;
END;
/
