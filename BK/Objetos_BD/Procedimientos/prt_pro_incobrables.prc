CREATE OR REPLACE PROCEDURE IT.PRT_PRO_INCOBRABLES
 (P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE, p_observacion in varchar2, p_secuencia in out number)
 IS
  vmodulo     NUMBER(3);
  vmodalidad  NUMBER(3);
  vfecha      DATE;
  vmensaje    VARCHAR2(2000);
  v_existe    number(01);
  no_procesa  EXCEPTION;
  verror      EXCEPTION;
  v_mto_prevision number(18,2);
  v_mto_trans     number(18,2);
  v_sal_cap       pr_cuotas.sal_capital%type;
  v_trans         ge_transacciones.cod_transaccion%type;
  v_concepto      ge_movimientos.concepto%type;
  v_cod_tra_pad   ge_transacciones.cod_transaccion%type;
  v_estado_cta    ta_cta_tarjetas.estado%type;
  v_est_anterior  ta_cta_tarjetas.estado%type;
  v_cod_tra_hij   ge_transacciones.cod_transaccion%type;
  rv_tarj         ta_cta_tarjetas%rowtype;
  r_pprev          pr_previsiones%rowtype;

  v_diferencia    number(18,2);
/* Insertar registros en la tabla de previsiones de tarjetas. */
PROCEDURE LP_INS_PREVISION
 (RP_PPREV IN PR_PREVISIONES%ROWTYPE
 )
 IS
BEGIN
   insert into ta_previsiones
     (fecha, nro_cuenta, monto,
      saldo, porcentaje,
      tot_gar_computables)
   values
     (rp_pprev.fecha, rp_pprev.nro_cuenta, rp_pprev.monto,
      rp_pprev.sal_capital, rp_pprev.porcentaje,
      rp_pprev.tot_gar_computables);
exception
   when others then
      raise_application_error(-20000,'Ins.Prev. '||sqlerrm);
END;
BEGIN
-- tiene que verificar si esta previsionado ?
-- tiene que poner estado I incobrable a cta tarjeta
-- tiene que generar asientos (sacar de cartera y pasar a ctas. de orden )

  -- Controlar si el módulo se encuentra habilitado
  pae_cnf.pr_ctr_modulo( nvl(pae_cnf.g_cod_modulo,5) );

   BEGIN
      select cod_modulo, cod_modalidad, estado
        into vmodulo, vmodalidad , v_est_anterior
        from ge_cuentas
       where nro_cuenta = p_nro_cuenta;
   EXCEPTION
    when others then
      vmensaje := 'No se pudo obtener los datos de la cuenta ' || to_char( p_nro_cuenta ) || '; ' || sqlerrm;
      raise verror;
   END;

   vfecha       := pag_cal.fu_obt_fec_actual( vmodulo );
   v_estado_cta := 'I';

   IF vmodulo IN (3,4) THEN     -- Cuenta de AHORROS
      vmensaje := 'No se puede pasar a Incobrables tipo de cta.';
      raise verror;
   ELSIF vmodulo = 5 THEN  -- Cuenta de Tarjetas
      BEGIN
         select *
           into rv_tarj
           from ta_cta_tarjetas
          where nro_cuenta = p_nro_cuenta;
      exception
         when no_data_found then
            raise_application_error(-20000,
            'Cuenta de tarjeta '||p_nro_cuenta||' no registrada');
      END;

      BEGIN
         select 1
           into v_existe
           from ta_cta_tarjetas
          where nro_cuenta = p_nro_cuenta
            for update nowait;

         update ta_cta_tarjetas
            set estado = v_estado_cta
          WHERE nro_cuenta = p_nro_cuenta;
      EXCEPTION
         WHEN OTHERS THEN
            if sqlcode = -54 then
               raise_application_error(-20000,'Reg. de tarjetas '||p_nro_cuenta||' bloqueado por otro usuario');
            elsif sqlcode <= -20000 then
               raise;
            else
               RAISE_APPLICATION_ERROR('-20005', 'Actu. Ta_Cta_Tarjetas cta '|| p_nro_cuenta );
            end if;
      END;

      v_sal_cap := nvl( rv_tarj.sal_facturar, 0 )   +
                   nvl( rv_tarj.sal_facturado, 0 )  +
                   nvl( rv_tarj.sal_financiado, 0 ) +
                   nvl( rv_tarj.sal_cuo_pendientes, 0 );

      pat_imp.g_hor_movim     := to_char( sysdate, 'HH24:MI:SS' );
      pat_imp.g_secuencia     := p_secuencia;
      pat_imp.g_cod_oficina   := rv_tarj.cod_oficina;
      pat_imp.g_cod_modulo    := rv_tarj.cod_modulo;
      pat_imp.g_cod_modalidad := rv_tarj.cod_modalidad;
      pat_imp.g_nro_cuenta    := rv_tarj.nro_cuenta;
      pat_imp.g_cod_moneda    := rv_tarj.cod_moneda;

      --generar novedades de cambio de estado para poder reversar
      insert into ge_cuentas_nov
           ( fecha, hora, cod_usuario, nro_cuenta, nro_detalle,
             cod_modulo, cod_modalidad, est_anterior, est_actual )
      values
           ( vfecha, pat_imp.g_hor_movim, user, P_NRO_CUENTA, null,
             rv_tarj.cod_modulo, rv_tarj.cod_modalidad, rv_tarj.estado, v_estado_cta );

   END IF;
   -- GENERACION DE ASIENTOS A INCOBRABLE
   v_cod_tra_pad := 945;
   v_cod_tra_hij := 954; ---929;
   -- x saldo capital
   v_mto_trans   := v_sal_cap;
   v_concepto    := nvl( p_observacion, 'TRANSF.CAPITAL A INCOBR.' );
   pat_imp.PR_INS_ASIENTO( v_cod_tra_pad, v_cod_tra_hij, v_mto_trans, v_concepto, v_est_anterior );
   -- A PREVISION
   v_mto_prevision := pat_imp.FU_OBT_PREVISION(P_NRO_CUENTA );
   IF nvl(v_mto_prevision,0) > 0 then
      v_mto_trans := v_mto_prevision;
      v_trans     := 957;
      v_concepto  := nvl(p_observacion, 'TRANSF.A PREVISION INCOB.');
      pat_imp.PR_INS_ASIENTO( v_cod_tra_pad, v_trans, v_mto_trans, v_concepto, v_est_anterior );
   END IF;
   -- Por la diferencia debo.
   v_diferencia := ( nvl( v_mto_prevision, 0) - nvl( v_sal_cap, 0 ) );
   ---
   If v_diferencia < 0 then
      v_mto_trans := v_diferencia*-1;
      v_trans     := 953;
      v_concepto  := nvl( p_observacion, 'TRANSF. A PERDIDA');
      pat_imp.PR_INS_ASIENTO( v_cod_tra_pad, v_trans, v_mto_trans, v_concepto, 'I' );
   Elsif v_diferencia > 0 then
      v_mto_trans := v_diferencia;
      v_trans     := 952;
      v_concepto  := nvl(p_observacion, 'TRANSF. A GANANCIA');
      pat_imp.PR_INS_ASIENTO( v_cod_tra_pad, v_trans, v_mto_trans, v_concepto, 'I' );
   End if;
   --- GENERA ASIENTO PARA CTAS. DE ORDEN
   v_mto_trans := v_sal_cap;
   v_trans     := 959;
   v_concepto  := nvl( p_observacion, 'TRANSF. A DEUDORES INCOBRABLES' );
   pat_imp.PR_INS_ASIENTO( v_cod_tra_pad, v_trans, v_mto_trans, v_concepto, 'I' );
   v_trans     := 960;
   v_concepto  := nvl( p_observacion, 'TRANSF. A CREDITOS INCOBRABLES' );
   pat_imp.PR_INS_ASIENTO( v_cod_tra_pad, v_trans, v_mto_trans, v_concepto, 'I' );

   -----* FIN ASIENTOS
   --- genera cambio de estado de tarjetas ---------
   v_cod_tra_pad := 945;
   v_trans       := 438;
   pat_imp.PR_INS_ASIENTO( v_cod_tra_pad, v_trans, null, p_observacion, 'I' );

   p_secuencia := pat_imp.g_secuencia;
   --- Si esta previsionando cerar la prevision
   if v_mto_prevision <> 0 then
      --- Insertar prevision
      r_pprev.nro_cuenta     := p_nro_cuenta;
      r_pprev.fecha          := vfecha;
      r_pprev.monto          := 0;
      r_pprev.sal_capital    := nvl(v_sal_cap,0);
      r_pprev.dev_no_cobrado := 0;
      r_pprev.porcentaje     := 0;
      r_pprev.tot_gar_computables := 0;
      lp_ins_prevision(r_pprev);
   end if;
EXCEPTION
  when verror then
    RAISE_APPLICATION_ERROR( -20000, 'Pro_Incobrables: ' || replace(nvl((vmensaje ), sqlerrm), 'ORA-', 'XXX'));
  when no_procesa then
    NULL;
  when others then
    RAISE_APPLICATION_ERROR( -20000, 'Pro_Incobrables: ' || replace(nvl((vmensaje ), sqlerrm), 'ORA-', 'XXX'));
END;
/

