CREATE OR REPLACE PROCEDURE IT.PRG_ELI_CUENTA
 (P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE
 ,P_COD_MODULO IN GE_CUENTAS.COD_MODULO%TYPE
 ,P_OBSERVACION IN GE_CTA_ELIMINADAS.OBS_ELIMINACION%TYPE
 )
 IS

/* Verificar si la cuenta tiene movimientos. */
FUNCTION LF_VER_MOV_CUENTA
 (P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE
 )
 RETURN BOOLEAN;
/* Verificar si la cuenta tiene débitos pendientes. */
FUNCTION LF_VER_DEB_PENDIENTE
 (P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE
 )
 RETURN VARCHAR2;
/* Verificar si la cuenta está en ctas combinadas. */
FUNCTION LF_VER_CTA_COMBINADA
 (P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE
 )
 RETURN BOOLEAN;
/* Inserta en la tabla GE_CTA_ELIMINADAS */
PROCEDURE LP_INS_CTA_ELIMINADA
 (P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE
 ,P_OBSERVACION IN GE_CTA_ELIMINADAS.OBS_ELIMINACION%TYPE
 );
--eliminar la cuenta de todas las tablas, x último de ge_cuentas
v_msj varchar2(2000);
v_nro_linea pr_lineas.nro_linea%type;
v_fec_apertura ge_cuentas.fec_apertura%type;
--
PROCEDURE LP_OBT_NRO_LINEA IS
begin
   select nro_linea
     into v_nro_linea
     from cx_cta_importaciones
    where estado <> 'C' --cancelada ya desaplica límite
      and nro_cuenta = p_nro_cuenta;
exception
   when others then
      v_nro_linea := null;
end;
/* Verificar si la cuenta tiene movimientos. */
FUNCTION LF_VER_MOV_CUENTA
 (P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE
 )
 RETURN BOOLEAN
 IS
v_existe number;
begin
   select 1
   into v_existe
   from gv_movimientos
   where nvl(monto,0) <> 0
   and nro_cuenta = p_nro_cuenta
   and reversado = 'N';
   return false;
exception
   when no_data_found then
      return true;
   when too_many_rows then
      return false;
   when others then
      return false;
end;
/* Verificar si la cuenta tiene débitos pendientes. */
FUNCTION LF_VER_DEB_PENDIENTE
 (P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE
 )
 RETURN VARCHAR2
 IS
cursor ver is
select 'GE_DEB_PENDIENTES' tabla, 'La Cta. posee Débitos Pendientes' descri
from GE_DEB_PENDIENTES
where nro_cuenta = p_nro_cuenta
and rownum=1
union
select 'AH_CTA_BANCOS' tabla,'Cta. utilizada como conciliatoria' descri
from AH_CTA_BANCOS
where nro_cuenta = p_nro_cuenta
and rownum=1
union
select 'AH_CTA_CAJEROS' tabla,'Cta. utilizada en Cajeros Automáticos' descri
from AH_CTA_CAJEROS
where nro_cuenta = p_nro_cuenta
and rownum=1
union
select 'AH_CTA_FICTICIAS' tabla,'Cta. utilizada en Cuentas Ficticias' descri
from AH_CTA_FICTICIAS
where nro_cuenta = p_nro_cuenta
and rownum=1
union
select 'AH_CTA_RESPALDADAS' tabla,'Cta. utilizada en Entidades Respaldadas' descri
from AH_CTA_RESPALDADAS
where nro_cuenta = p_nro_cuenta
and rownum=1
union
select 'AH_TAR_DEBITOS' tabla, 'Cta. utilizada en Tarjetas de Débito' descri
from AH_TAR_DEBITOS G
where nro_cuenta = p_nro_cuenta
and cod_est_solicitud not in (1,16) /* Tarjetas Rechazadas y Anuladas*/
and rownum=1
union
select 'CC_CHEQUERAS' tabla,'La Cta. posee Chequeras' descri
from CC_CHEQUERAS
where nro_cuenta = p_nro_cuenta
and rownum=1
union
select 'CC_LIN_SOBREGIROS' tabla,'La Cta. posee Líneas de Sobregiro' descri
from CC_LIN_SOBREGIROS G
where nro_cuenta = p_nro_cuenta
and rownum=1
union
select 'CC_SOL_CHEQUERAS' tabla,'La Cta. posee Solicitudes de Chequeras' descri
from CC_SOL_CHEQUERAS
where nro_cuenta = p_nro_cuenta
and rownum=1
union
select 'GE_AUT_PEDIDOS' tabla,'La Cta. posee Autorización Pendiente' descri
from ge_movimientos m,
     ge_aut_pedidos p
where m.fecha = p.fecha
  and m.hora = p.hora
  and m.cod_usuario = p.cod_usuario
  and nro_cuenta = p_nro_cuenta
  and p.estado = 'S'
and rownum=1
union--JIRA DYDMR-1416 -- Se agrega el control de previsiones al momento de eliminar la cuenta para informar error de FK
select 'CC_PREVISIONES' tabla,'La Cta. posee previsiones, la eliminacion de una prevision debe estar autorizada por Contabilidad y ser canalizada por contingente' descri
from CC_PREVISIONES
where nro_cuenta = p_nro_cuenta
and rownum=1;

v_msj varchar2(1000);
begin
   for reg in ver loop
      v_msj:= reg.descri ||'<'||reg.tabla||'>';
      exit;
   end loop;
   if v_msj is null then
      return 'OK';
   else
      return v_msj;
   end if;
exception
   when others then
      raise_application_error(-20002,'Verif.Cta -'||sqlerrm);
end;
/* Verificar si la cuenta está en ctas combinadas. */
FUNCTION LF_VER_CTA_COMBINADA
 (P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE
 )
 RETURN BOOLEAN
 IS
--ver si existe en alguna emitir msj q existe y de qué cuenta es
v_existe number;
begin
   select 1
   into v_existe
   from cc_cta_combinadas
   where nro_cta_ahorro = p_nro_cuenta
   union
   select 1
   from cc_cta_combinadas
   where nro_cta_cte = p_nro_cuenta;
   return false;
exception
   when no_Data_found then
      return true;
   when too_many_rows then
      return false;
   when others then
      return false;
end;
/* Inserta en la tabla GE_CTA_ELIMINADAS */
PROCEDURE LP_INS_CTA_ELIMINADA
 (P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE
 ,P_OBSERVACION IN GE_CTA_ELIMINADAS.OBS_ELIMINACION%TYPE
 )
 IS
 v_error varchar2(1000);
begin
   insert into ge_cta_eliminadas
      (nro_cuenta, dig_verificador, denominacion, cod_modulo, cod_modalidad,
      cod_oficina, estado, fec_cam_estado, sal_contable, cod_moneda, fec_apertura,
      fec_vencimiento, cod_cau_cancelacion, cod_tasa, fre_extracto, tas_personalizada,
      tra_prohibida, ret_personalizada, dia_atraso, max_atraso, pro_atraso, sal_promedio,
      mto_mora, val_tasa, est_verificacion, cod_usu_verificador, fec_verificacion,
      obs_verificacion, /*en_juicio, */ obs_eliminacion)
      select nro_cuenta, dig_verificador, denominacion, cod_modulo, cod_modalidad,
         cod_oficina, estado, fec_cam_estado, sal_contable, cod_moneda, fec_apertura,
         fec_vencimiento, cod_cau_cancelacion, cod_tasa, fre_extracto, tas_personalizada,
         tra_prohibida, ret_personalizada, dia_atraso, max_atraso, pro_atraso, sal_promedio,
         mto_mora, val_tasa, est_verificacion, cod_usu_verificador, fec_verificacion,
         obs_verificacion,/* en_juicio,*/ p_observacion
      from ge_cuentas
      where nro_cuenta = p_nro_cuenta;
exception
   when others then
      v_error := sqlerrm;
      RAISE_APPLICATION_ERROR(-20002,'Ins. Cta. Eliminada-'||substr(v_error,instr(v_error,':')+1));--para q no muestre el ora otra vez
end;
begin
   --verificar que no existan movimientos de dinero de la cuenta para eliminar
   if not LF_VER_MOV_CUENTA(p_nro_cuenta) then
      raise_application_error(-20022,'La Cta. ya posee Movimientos ');
   end if;
   --verifica que no exista en las tablas
   v_msj := LF_VER_DEB_PENDIENTE(p_nro_cuenta);
   if v_msj <> 'OK' THEN
      raise_application_error(-20022,v_msj);
   end if;
   --verifica que no exista en cuentas combinadas
   if not LF_VER_CTA_COMBINADA(p_nro_cuenta) then
      raise_application_error(-20022,'Cta. utilizada en Ctas. Combinadas ');
   end if;
   --si paso todos los controles, eliminar
   select fec_apertura into v_fec_apertura from ge_cuentas where nro_cuenta = p_nro_cuenta;
   --
   --elimina las de movimiento
   delete AH_MOVIMIENTOS_HIS where nro_cuenta = p_nro_cuenta;
   delete CC_MOVIMIENTOS_HIS where nro_cuenta = p_nro_cuenta;
   delete CX_MOVIMIENTOS_HIS where nro_cuenta = p_nro_cuenta;
   --delete TA_MOVIMIENTOS_HIS where nro_cuenta = p_nro_cuenta; tarj y prest NO
   --delete PR_MOVIMIENTOS_HIS where nro_cuenta = p_nro_cuenta;
   delete CJ_MOVIMIENTOS_HIS where nro_cuenta = p_nro_cuenta;
   delete CJ_MOVIMIENTOS_NOC where nro_cuenta = p_nro_cuenta;
   delete CJ_MOVIMIENTOS where nro_cuenta = p_nro_cuenta;
   delete GE_MOVIMIENTOS_NOC where nro_cuenta = p_nro_cuenta;
   delete GE_MOV_PENDIENTES where nro_cuenta = p_nro_cuenta;
   delete GE_MOVIMIENTOS where nro_cuenta = p_nro_cuenta;
   delete MD_MOVIMIENTOS_HIS a where a.nro_cuenta = p_nro_cuenta and a.cod_modulo=10;
   -- se agrega filtro por fecha para que busque a partir de la fecha de apertura de la cuenta DYDMR-12315
   delete GE_SAL_DIARIOS where nro_cuenta = p_nro_cuenta and fecha >= v_fec_apertura;
   --
   --las tablas de informes superintendencia ->sin restriccion
   delete SB_CLA_OPERACIONES where nro_cuenta = p_nro_cuenta;
   delete SB_FDG_DEPOSITOS where nro_cuenta = p_nro_cuenta;
   delete SB_DEP_OFICINAS_DET where nro_cuenta = p_nro_cuenta;
   delete SB_FDG_DEP_PERSONAS where nro_cuenta = p_nro_cuenta;
   delete SB_FDG_DEUDAS where nro_cuenta = p_nro_cuenta;
   delete SB_FDG_DEU_PERSONAS where nro_cuenta = p_nro_cuenta;
   delete SB_ENCAJES_ESP where nro_cuenta = p_nro_cuenta;
   delete SB_ESTRATIFICACIONES_DEP_DET where nro_cuenta = p_nro_cuenta;
   delete SB_LIQUIDEZ_DET where nro_cuenta = p_nro_cuenta;
   delete SB_TAS_APE_SEMANALES where nro_cuenta = p_nro_cuenta;

   --las de extracto sin restricción
   delete GE_EXT_CLI_CUENTAS_TMP where nro_cuenta = p_nro_cuenta;
   delete GE_EXT_RESUMENES_TMP where nro_cuenta = p_nro_cuenta;
   delete GE_EXT_CLI_MOVIMIENTOS_TMP where nro_cuenta = p_nro_cuenta;
   delete GE_EXT_CLI_MOVIMIENTOS where nro_cuenta = p_nro_cuenta;
   delete GE_EXT_RESUMENES where nro_cuenta = p_nro_cuenta;
   delete GE_EXT_CLI_CUENTAS where nro_cuenta = p_nro_cuenta;

   --las de CRM
   delete CR_EXP_CUENTAS where nro_cuenta = p_nro_cuenta;
   --delete CR_PEDIDOS where nro_cuenta = p_nro_cuenta;
   delete CR_REF_COMERCIALES where nro_cuenta = p_nro_cuenta;

   if p_cod_modulo = 3 then
      --ahorros--si se verificaron maestros estas se borran nomás
      delete AH_CAPITALIZACIONES where nro_cuenta = p_nro_cuenta;
      update AH_CER_ANULADOS set nro_cuenta = null
       where nro_cuenta = p_nro_cuenta;
      delete AH_TAR_DEB_PINES where nro_cuenta = p_nro_cuenta;
      delete AH_TAR_DEBITOS where nro_cuenta = p_nro_cuenta;
      delete AH_TAR_DEB_CUENTAS where (nro_cuenta = p_nro_cuenta OR nro_cta_relacionada = p_nro_cuenta); -- DYDMR-699_SPI-3950 / RABP_20-08-2014
      delete AH_CUP_BLOQUEADOS where nro_cuenta = p_nro_cuenta;
      delete AH_DEVENGADOS_HIS where nro_cuenta = p_nro_cuenta;
      delete AH_DEVENGADOS where nro_cuenta = p_nro_cuenta;
      delete AH_RETENCIONES where nro_cuenta = p_nro_cuenta;
      delete AH_SAL_MENSUALES where nro_cuenta = p_nro_cuenta;
      delete AH_CUPONES where nro_cuenta = p_nro_cuenta;--trigger no deja eliminar emitidos
      delete AH_CTA_VISTAS_NOC where nro_cuenta = p_nro_cuenta;
   elsif p_cod_modulo = 4 then
      --cta_ctes
      delete AH_TAR_DEB_PINES where nro_cuenta = p_nro_cuenta;
      delete AH_TAR_DEBITOS where nro_cuenta = p_nro_cuenta;
      delete AH_TAR_DEB_CUENTAS where (nro_cuenta = p_nro_cuenta OR nro_cta_relacionada = p_nro_cuenta); -- DYDMR-699_SPI-3950 / RABP_20-08-2014     
      delete CC_CHE_ANULADOS where nro_cuenta = p_nro_cuenta;
      delete CC_CHE_CERTIFICADOS where nro_cuenta = p_nro_cuenta;
      delete CC_CHE_GER_EMITIDOS where nro_cuenta = p_nro_cuenta;
      delete CC_CHE_ORD_NO_PAGOS where nro_cuenta = p_nro_cuenta;
      delete CC_CHE_PAGADOS where nro_cuenta = p_nro_cuenta;
      delete CC_CHE_RECIBIDOS where nro_cuenta = p_nro_cuenta;
      delete CC_CHE_RECIBIDOS_TMP where nro_cuenta = p_nro_cuenta;
      delete CC_CHE_REMITIDOS where nro_cuenta = p_nro_cuenta;
      delete CC_CHE_REMITIDOS_TMP where nro_cuenta = p_nro_cuenta;
      delete CC_CHEQUERAS where nro_cuenta = p_nro_cuenta;
      delete CC_SOL_CHEQUERAS where nro_cuenta = p_nro_cuenta;
      delete CC_LIN_SOBREGIROS where nro_cuenta = p_nro_cuenta;
      delete CC_LIQ_SOBREGIROS where nro_cuenta = p_nro_cuenta;
      delete CC_SAL_MENSUALES where nro_cuenta = p_nro_cuenta;
      delete CC_SOBREGIROS_RES where nro_cuenta = p_nro_cuenta;
      delete CC_SOB_GASTOS where nro_cuenta = p_nro_cuenta;
      delete CC_SOBREGIROS where nro_cuenta = p_nro_cuenta;
      delete CC_CTA_CORRIENTES_NOC where nro_cuenta = p_nro_cuenta;
   elsif p_cod_modulo = 8 then
      delete CX_CTA_GARANTIAS where nro_cuenta = p_nro_cuenta;
   end if;

   --datos generales
   delete GE_PAG_COMERCIOS where nro_cuenta = p_nro_cuenta;
   delete GE_PAG_COMERCIOS_TMP where nro_cuenta = p_nro_cuenta;
   delete GE_PAG_SUELDOS where nro_cuenta = p_nro_cuenta;
   delete GE_PAG_SUELDOS_TMP where nro_cuenta = p_nro_cuenta;
   delete GE_CLA_OPERACIONES where nro_cuenta = p_nro_cuenta;
   delete GE_CLA_OPERACIONES_HIS where nro_cuenta = p_nro_cuenta;
   delete GE_AUTORIZACIONES where nro_cuenta = p_nro_cuenta;
   delete GE_AUTORIZACIONES_HIS where nro_cuenta = p_nro_cuenta;  /*AP 1558*/ 
   delete GE_BLOQUEOS where nro_cuenta = p_nro_cuenta;
   delete GE_CANCELACIONES where nro_cuenta = p_nro_cuenta;
   delete GE_CONTROLES where nro_cuenta = p_nro_cuenta;
   delete GE_CTA_DAT_ADICIONALES where nro_cuenta = p_nro_cuenta;
   delete GE_CHEQUES_DET where nro_cuenta = p_nro_cuenta;
   delete GE_CUENTAS_NOV where nro_cuenta = p_nro_cuenta;
   delete GE_DIR_ENVIOS where nro_cuenta = p_nro_cuenta;
   delete GE_RET_CUENTAS where nro_cuenta = p_nro_cuenta;
   delete GE_TAS_FECHAS where nro_cuenta = p_nro_cuenta;
   delete GE_TAS_RANGOS where nro_cuenta = p_nro_cuenta;
   delete GE_TRA_PROHIBIDAS where nro_cuenta = p_nro_cuenta;
   delete GE_DOC_CATASTROS where nro_cuenta = p_nro_cuenta;--DYDMR-1651 
   delete BW_NOT_SUSCRIPCIONES where nro_cuenta = p_nro_cuenta; -- DYDMR-11162

   --desactivar trigger de ge_cta_clientes
   delete GE_CTA_CLIENTES where nro_cuenta = p_nro_cuenta;
   --se inserta en la tabla antes de eliminar
   LP_INS_CTA_ELIMINADA(p_nro_cuenta, p_observacion);
   if p_cod_modulo = 10 Then
     --Se eliminará por el formulario GPELICTA.
     if nvl(pae_cnf.G_PROGRAMA,'X') = 'GPELICTA' Then
        --wa:19/10/2010 para eliminar datos de Mesa de Dinero
        Delete MD_GARANTIAS where nro_cuenta=p_nro_cuenta;
        Delete MD_DOC_DETALLES where nro_cuenta=p_nro_cuenta;
      end if;
   end if;
   --desaplica límite
   if p_cod_modulo = 8 then
      lp_obt_nro_linea;
      if v_nro_linea is not null then
         prp_rec_apl_limite(v_nro_linea);
      end if;
   end if;

   --borrar masters
   delete AH_CTA_CERTIFICADOS where nro_cuenta = p_nro_cuenta; --33 master
   delete AH_CTA_VISTAS where nro_cuenta = p_nro_cuenta; --31 master
   delete CC_CTA_CORRIENTES where nro_cuenta = p_nro_cuenta; --master
   delete CX_CUOTAS where nro_cuenta = p_nro_cuenta; --hijo
   delete CX_CTA_IMPORTACIONES where nro_cuenta = p_nro_cuenta; --master
   delete CX_CTA_EXPORTACIONES where nro_cuenta = p_nro_cuenta; --master
   delete CX_CTA_COBRANZAS where nro_cuenta = p_nro_cuenta; --master
   --- CNFREINT-1 - REPO INTERBANCARIO - LCABRERA JULIO/15
   update MD_CTA_DOCUMENTOS set nro_cta_padre = null where nro_cta_padre = p_nro_cuenta;
   delete MD_CUO_INSTRUMENTOS where nro_cuenta = p_nro_cuenta;
   delete MD_INSTRUMENTOS_DET where nro_cta_repo = p_nro_cuenta;   
   delete MD_CTA_DOCUMENTOS where nro_cuenta = p_nro_cuenta;
   --ge_cuentas se borra x trigger al borrar los masters
exception
   when others then
      v_msj := sqlerrm;
      rollback;
      if sqlcode <= -20000 then
         raise;
      else
         raise_application_error(-20222,sqlerrm);
      end if;
end;
/

