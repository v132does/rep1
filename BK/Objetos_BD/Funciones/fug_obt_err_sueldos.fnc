CREATE OR REPLACE FUNCTION IT.FUG_OBT_ERR_SUELDOS
 (P_COD_PROCESO IN GE_PAG_SUELDOS_TMP.COD_PROCESO%TYPE
 ,P_TIPO IN VARCHAR2 := 'D'
 )
 RETURN VARCHAR
 IS
BEGIN
   if p_cod_proceso = 1 then
      if p_tipo = 'D' then
         return 'Cuenta tiene transaccion prohibida';
      else
         return 'TRA.PROHIB';
      end if;
   elsif p_cod_proceso = 2 then
      if p_tipo = 'D' then
         return 'Cuenta con Trans.Proh. Duplicada';
      else
         return 'TRA.PRO.DU';
      end if;
   elsif p_cod_proceso = 3 then
      if p_tipo = 'D' then
         return 'ERROR - Cuando buscaba en GE_TRA_PROHIBIDAS ';
      else
         return 'BUS.TR.PRO';
      end if;
   elsif p_cod_proceso = 4 then
      if p_tipo = 'D' then
         return 'La Cuenta no posee Cuenta Corriente Combinada ';
      else
         return 'SIN.CC.COM';
      end if;
   elsif p_cod_proceso = 5 then
      if p_tipo = 'D' then
         return 'ERROR - Cuando buscaba en CTA_CTE_COMBINADA ';
      else
         return 'BUS.CC.COM';
      end if;
   elsif p_cod_proceso = 6 then
      if p_tipo = 'D' then
         return 'Transaccion inexistente';
      else
         return 'TRAN.INEXI';
      end if;
   elsif p_cod_proceso = 7 then
      if p_tipo = 'D' then
         return 'Error al obtener datos de Retención';
      else
         return 'OBT.RETENC';
      end if;
   elsif p_cod_proceso = 8 then
      if p_tipo = 'D' then
         return 'ERROR. No se puede cobrar cargos - transaccion prohibida ';
      else
         return 'COB.CAR.TP';
      end if;
   elsif p_cod_proceso = 9 then
      if p_tipo = 'D' then
	     return 'ERROR. No se puede cobrar cargos a esta cuenta - Tiene Autorizacion';
      else
         return 'COBCAR.AUT';
      end if;
   elsif p_cod_proceso = 10 then
      if p_tipo = 'D' then
   	     return 'ERROR. Esta operacion no permite este tipo de Tasas';
      else
         return 'TASA INV.';
      end if;
   elsif p_cod_proceso = 11 then
      if p_tipo = 'D' then
         return 'Error en Calcula_cargo_e_impuesto';
      else
         return 'CAL.CARIMP';
      end if;
   elsif p_cod_proceso = 12 then
      if p_tipo = 'D' then
	     return 'Cuenta Inexistente!!!';
      else
         return 'CTA.INEXIS';
      end if;
   elsif p_cod_proceso in(13,14) then
      if p_tipo = 'D' then
         return 'Estado del Modulo incorrecto';
      else
         return 'MOD.INCORR';
      end if;
   elsif p_cod_proceso = 15 then
      if p_tipo = 'D' then
         return 'Tipo de cuenta no valido';
      else
         return 'TP.CTA.INV';
      end if;
   elsif p_cod_proceso = 16 then
      if p_tipo = 'D' then
         return 'Error en pag_cta.pr_obt_cuenta ';
      else
         return 'OBT.CTA.';
      end if;
   elsif p_cod_proceso = 17 then
      if p_tipo = 'D' then
         return 'ERROR: Estado no identificado';
      else
         return 'ESTADO INV';
      end if;
   elsif p_cod_proceso = 18 then
      if p_tipo = 'D' then
         return 'ERROR - Cuando buscaba en GE_EST_CUENTAS ';
      else
         return 'GE_EST_CTA';
      end if;
   elsif p_cod_proceso = 19 then
      if p_tipo = 'D' then
         return 'Cuenta Bloqueada';
      else
         return 'CTA.BLOQ';
      end if;
   --DYDMR-8896 Incidencia SAU - ITGF - Error Acreditación de Pasantes Universitarios.
   elsif p_cod_proceso = 20 then
      if p_tipo = 'D' then
       return 'ERROR - Cuando buscaba en RH_EMPLEADOS';
      else
         return 'ERR_CTA_RH';
      end if;      
   elsif p_cod_proceso = 21 then
      if p_tipo = 'D' then
         return 'Esta operacion no afecta al saldo';
      else
         return 'NO AFE SAL';
      end if;
   elsif p_cod_proceso = 22 then
      if p_tipo = 'D' then
         return 'Error con el Nro Cuenta';
      else
         return 'NRO.CTA';
      end if;
   elsif p_cod_proceso = 23 then
      if p_tipo = 'D' then
         return 'Cuenta Llaveada';
      else
         return 'CTA.LLAVEA';
      end if;
   elsif p_cod_proceso = 24 then
      if p_tipo = 'D' then
         return 'No se puede DEBITAR a Cta. con el estado actual';
      else
         return 'DB.EST.INV';
      end if;
   elsif p_cod_proceso = 25 then
      if p_tipo = 'D' then
         return 'Cuenta con Saldo Insuficiente';
      else
         return 'SAL.INSUFI';
      end if;
   elsif p_cod_proceso = 26 then
      if p_tipo = 'D' then
         return 'Moneda Cta.Combinada es dif.';
      else
         return 'MON.CTA.COM';
      end if;
   elsif p_cod_proceso = 27 then
      if p_tipo = 'D' then
         return 'No se puede DEBITAR a Cta. Comb. con el estado actual';
      else
         return 'EST.INV.CC';
      end if;
   elsif p_cod_proceso in (28,29,31,36) then
      if p_tipo = 'D' then
         return 'Cuenta con Saldo Insuficiente';
      else
         return 'SAL.INSUFI';
      end if;
   elsif p_cod_proceso in (30,32) then
      if p_tipo = 'D' then
         return 'No se puede DEBITAR por estado incorrecto ';
      else
         return 'DB.EST.INV';
      end if;
   elsif p_cod_proceso = 33 then
      if p_tipo = 'D' then
         return 'No se puede ACREDITAR a Cta. con el estado actual';
      else
         return 'CR.EST.INV';
      end if;
   elsif p_cod_proceso = 34 then
      if p_tipo = 'D' then
         return 'Estado Incorrecto al Acreditar';
      else
         return 'CR.EST.INV';
      end if;
   elsif p_cod_proceso in (35,42) then
      if p_tipo = 'D' then
         return 'Tipo Operacion debe ser (D)ebito o (C)redito';
      else
         return 'TIP.OPERAC';
      end if;
   elsif p_cod_proceso = 37 then
      if p_tipo = 'D' then
         return 'Plazo Fijo sin Interés o Saldo Insuficiente';
      else
         return 'SAL.INSUFI';
      end if;
   elsif p_cod_proceso = 38 then
      if p_tipo = 'D' then
         return 'Certificado sin Interés';
      else
         return 'S/INTERES';
      end if;
   elsif p_cod_proceso = 39 then
      if p_tipo = 'D' then
         return 'No se puede DEBITAR por estado incorrecto';
      else
         return 'DB.EST.INV';
      end if;
   elsif p_cod_proceso = 40 then
      if p_tipo = 'D' then
         return 'Monto a acreditar supera al Capital';
      else
         return 'MTOVSCAP';
      end if;
   elsif p_cod_proceso = 41 then
      if p_tipo = 'D' then
         return 'Estado de la cuenta no permite Creditos';
      else
         return 'EST.INV.CR';
      end if;
   elsif p_cod_proceso = 43 then
      if p_tipo = 'D' then
         return 'Moneda dif. de la Operación';
      else
         return 'MON.DIF.OPE';
      end if;
   elsif p_cod_proceso = 44 then
      if p_tipo = 'D' then
         return 'Tipo de Cta. no habilitada';
      else
         return 'TIP.CTA.NHA';
      end if;
   elsif p_cod_proceso = 47 then  --- pago sueldos
         return 'No existen datos del Ente';
   elsif p_cod_proceso = 48 then  --- pago sueldos
         return 'Cta.Débito del txt no corresponde a Ente';
   elsif p_cod_proceso = 70 then  --- Pago de aguinaldos
         return 'No posee Caja de Ahorro para traspaso de Aguinaldo.';
   elsif p_cod_proceso = 71 then  --- Pago de aguinaldos
         return 'Existe mas de una Caja de Ahorro para traspaso de Aguinaldo.';   
   elsif p_cod_proceso = 73 then
         return 'Cuenta no permite crédito concepto Aguinaldo.';     

   --- a partir del 51 para errores de pago a proveedores ---no se usa
   elsif p_cod_proceso = 51 then
      return 'Cta.Débito no existe';
   elsif p_cod_proceso = 52 then
      return 'Error en modalid.Cta.Débito';
   elsif p_cod_proceso = 53 then
      return 'Error en Estado cta.ahorro';
   elsif p_cod_proceso = 54 then
      return 'Cta.comb.p/ahorro vista';
   elsif p_cod_proceso = 55 then
      return 'Estado de la cta.inválido';
   elsif p_cod_proceso = 56 then
      return 'Moneda cta.credito<>mon.cta.debito';
   elsif p_cod_proceso = 57 then
      return 'No existe cta.Crédito';
   elsif p_cod_proceso = 58 then
      return 'Error en modalid.Cta.Crédito';
   elsif p_cod_proceso = 59 then
      return 'Tipo comprobante con error';
   elsif p_cod_proceso = 60 then
      return 'Forma de Pago son : Crédito o Cheque Gerencia';
   elsif p_cod_proceso = 61 then
      return 'No tiene Beneficiario p/Cheque';
   elsif p_cod_proceso = 62 then
      return 'No tiene Nro. Orden de Pago';
   elsif p_cod_proceso = 63 then
      return 'No tiene Nro. de Factura';
   elsif p_cod_proceso = 64 then
      return 'No tiene Monto a Pagar';
   elsif p_cod_proceso = 65 then
      return 'Cta.Débito no corresponde a Empresa';
   elsif p_cod_proceso = 66 then
      return 'No tiene Cuenta para el Crédito';
   /*
   || rabf 10/02/2011 - despliega en el error la descripción del estado de la
   || cuenta en lugar del código de error 55 - 'Estado de la cta.inválido'.
   || C,67-CANCELADA
   || T,68-BLOQUEO TOTAL
   || P,69-CERRADA
   || X,70-VERIFICACION
   */
   elsif p_cod_proceso = 67 then
      return 'Cuenta Cancelada';
   elsif p_cod_proceso = 68 then
      return 'Cuenta c/Bloqueo Total';
   elsif p_cod_proceso = 69 then
      return 'Cuenta Cerrada';
   elsif p_cod_proceso = 70 then
      return 'Cuenta en Verificación';
   ---
   elsif p_cod_proceso = 89 then
      return 'Operación con Monto Cero';
   elsif p_cod_proceso = 90 then
      if p_tipo = 'D' then
	     return 'Nro. de documento no pertenece a la cuenta';
      end if;
   else
      return 'Er. '||p_cod_proceso;
   end if;
   return 'Error desconocido';
exception
when no_data_found then
   return 'Error desconocido';
END;
/

