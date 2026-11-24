CREATE OR REPLACE PROCEDURE IT.PRG_ELI_PERSONA
 (P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE
 ,P_OBSERVACION IN VARCHAR2
 )
 IS
-- Cursor para eliminar la garantia de sobregiros
cursor lineas is select nro_secuencia from cc_lin_sobregiros where cod_persona = p_cod_persona;
/* Verificar si la persona existe en alguna tabla. */
FUNCTION LF_VER_PER_TABLA
 (P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE
 )
 RETURN VARCHAR2;
/* Insertar en la tabla ba_per_eliminadas. */
PROCEDURE LP_INS_PER_ELIMINADA
 (P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE
 ,P_OBSERVACION IN VARCHAR2
 );
--eliminar la persona de todas las tablas, x último de ba_personas
v_msj varchar2(2000);

/* Verificar si la persona existe en alguna tabla. */
FUNCTION LF_VER_PER_TABLA
 (P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE
 )
 RETURN VARCHAR2
 IS
cursor ver is
select '<BA_USUARIOS>' tabla, 'La Persona corresponde a un usuario del sistema ' descri
from BA_USUARIOS
where cod_persona = p_cod_persona
and rownum=1
union
select '<BA_VINCULOS>' tabla,'La Persona posee vínculos con la persona '||cod_per_vinculo descri
from BA_VINCULOS
where cod_persona = p_cod_persona
and rownum=1
union
select '<BA_VINCULOS>' tabla,'La Persona esta vinculada al Cod. '||cod_persona descri
from BA_VINCULOS
where cod_per_vinculo = p_cod_persona
and rownum=1
union
select '<GE_BANCOS>' tabla,'La Persona corresponde a un Banco ' descri
from GE_BANCOS
where cod_persona = p_cod_persona
and rownum=1
union
/* no hace falta controlar, solo si tiene cuentas
select '<GE_CLIENTES>' tabla,'La Persona corresponde a un Cliente ' descri
from GE_CLIENTES
where cod_persona = p_cod_persona
and rownum=1
union
*/
select '<GE_CTA_CLIENTES>' tabla,'La Persona posee Cuentas ' descri
from GE_CTA_CLIENTES
where cod_persona = p_cod_persona
and rownum=1
union
select '<GE_CLIENTES_HIS>' tabla,'La Persona posee registros para Categorización de Operaciones ' descri
from GE_CLIENTES_HIS
where cod_persona = p_cod_persona
and rownum=1
union
select '<GE_ENTES>' tabla, 'La Persona corresponde a un Ente ' descri
from GE_ENTES
where cod_persona = p_cod_persona
and rownum=1
union
select '<GE_PAR_GENERALES>' tabla,'La Persona corresponde a la Entidad ' descri
from GE_PAR_GENERALES
where cod_persona = p_cod_persona
and rownum=1
union
select '<GE_PER_INFORMES>' tabla,'La Persona se encuentra en Informconf ' descri
from GE_PER_INFORMES
where cod_persona = p_cod_persona
and rownum=1
union
select '<GE_PER_INHIBIDAS>' tabla,'La Persona está Inhibida ' descri
from GE_PER_INHIBIDAS
where cod_persona = p_cod_persona
and rownum=1
union
select '<GE_SOLICITUDES>' tabla,'La Persona posee Solicitud de Tarjeta ' descri
from GE_SOLICITUDES
where cod_persona = p_cod_persona
and rownum=1
union
select '<GE_SOL_ADICIONALES>' tabla,'La Persona posee Adicionales de Solicitudes ' descri
from GE_SOL_ADICIONALES
where cod_persona = p_cod_persona
and rownum=1
union
select '<GE_SOL_CODEUDORES>' tabla,'La Persona es Codeudora de una Solicitud ' descri
from GE_SOL_CODEUDORES
where cod_persona = p_cod_persona
and rownum=1
union
select '<PR_GARANTIAS>' tabla,'La Persona posee Garantías ' descri
from PR_GARANTIAS
where cod_persona = p_cod_persona
and rownum=1
union
select '<PR_SIMULACIONES>' tabla,'La Persona posee Simulación de Préstamos ' descri
from PR_SIMULACIONES
where cod_persona = p_cod_persona
and rownum=1
union
select '<PR_SOLICITUDES>' tabla,'La Persona posee Solicitud de Préstamos' descri
from PR_SOLICITUDES
where cod_persona = p_cod_persona
and rownum=1
union
select '<AH_TAR_DEBITOS>' tabla, 'La Persona posee Tarjetas de Débitos ' descri
from AH_TAR_DEBITOS
where cod_persona = p_cod_persona
and cod_est_solicitud not in (1,16) /* Tarjetas Rechazadas y Anuladas*/
and rownum=1
union
select '<CS_CON_PERSONAS>' tabla, 'La Persona posee Contratos de Caja de Seguridad ' descri
from CS_CON_PERSONAS
where cod_persona = p_cod_persona
and rownum=1
union
select '<CO_INF_PERSONAS>' tabla, 'La Persona posee Datos en Informconf ' descri
from CO_INF_PERSONAS
where cod_persona = p_cod_persona
and rownum=1
union
select '<CO_INF_OPE_DIARIAS>' tabla, 'La Persona posee Datos a ser enviados a Informconf ' descri
from CO_INF_OPE_DIARIAS
where cod_persona = p_cod_persona
and rownum=1
union
select '<GE_MOVIMIENTOS>' tabla, 'La persona tiene movimientos del dia ' descri
from GE_MOVIMIENTOS
where cod_persona = p_cod_persona
and rownum=1
union
select '<BW_MOVIMIENTOS>' tabla, 'La persona tiene movimientos del Homebanking y/o TAS ' descri
from BW_MOVIMIENTOS
where (cod_per_principal = p_cod_persona or cod_per_ingreso = p_cod_persona)
and rownum=1;

v_msj varchar2(1000);
begin
   for reg in ver loop
      v_msj:= substr(reg.descri,1,length(reg.descri))||' '||reg.tabla;
      exit;
   end loop;
   if v_msj is null then
      return 'OK';
   else
      return v_msj;
   end if;
exception
   when others then
      raise_application_error(-20002,'Verif.Pers -'||sqlerrm);
end;
/* Insertar en la tabla ba_per_eliminadas. */
PROCEDURE LP_INS_PER_ELIMINADA
 (P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE
 ,P_OBSERVACION IN VARCHAR2
 )
 IS
begin
   insert into ba_per_eliminadas
      (cod_persona, nom_completo, tipo, cod_usu_promotor, cod_tip_documento,
      nro_documento, cod_pais, dir_correo, cod_actividad, ref_bancaria,
      ref_comercial, ref_laboral, ref_tarjeta, tot_ingresos, ing_presuntos,
      egr_presuntos, est_verificacion, cod_usu_verificador, nom_per_informo,
      obs_verificacion, fec_verificacion, tip_relacion, fec_vto_documento,
      obs_eliminacion, tip_iva, tas_personalizada, recibe_sms, cod_rub_economico)
      select cod_persona, nom_completo, tipo, cod_usu_promotor, cod_tip_documento,
         nro_documento, cod_pais, dir_correo, cod_actividad, ref_bancaria,
         ref_comercial, ref_laboral, ref_tarjeta, tot_ingresos, ing_presuntos,
         egr_presuntos, est_verificacion, cod_usu_verificador, nom_per_informo,
         obs_verificacion, fec_verificacion, tip_relacion, fec_vto_documento,
         p_observacion, tip_iva, tas_personalizada, recibe_sms, cod_rub_primario
      from ba_personas
      where cod_persona = p_cod_persona;
exception
   when others then
      RAISE_APPLICATION_ERROR(-20002,'Ins. Pers. Eliminada- '||sqlerrm);
end;
begin
   --verificar que no exista la persona en las tablas dadas
   v_msj := LF_VER_PER_TABLA(p_cod_persona);
   if v_msj <> 'OK' THEN
      raise_application_error(-20022,v_msj);
   end if;
   -- no hay problemas para eliminar la persona
   begin
       --
       delete IG_CLI_LOGROS where cod_persona = p_cod_persona;
       delete IG_OPERACIONES where cod_persona = p_cod_persona;
       delete IG_OPE_RES_CLIENTES where cod_persona = p_cod_persona;
       delete IG_REN_VALORES where cod_persona = p_cod_persona;
       --si pasó todos los controles, eliminar
       -- Elimina las garantías de los sobregiros
       for l in lineas loop
         delete cc_lin_sob_garantias where nro_secuencia = l.nro_secuencia;
       end loop;
       -- Elimina los sobregiros.
       delete cc_lin_sobregiros where cod_persona = p_cod_persona;
       delete GE_CLIENTES where cod_persona = p_cod_persona;
       --las tablas de informes superintendencia ->sin restricción
       delete SB_CLA_OPERACIONES where cod_persona = p_cod_persona;
       delete SB_FDG_DEP_PERSONAS where cod_persona = p_cod_persona;
       delete SB_FDG_DEU_PERSONAS where cod_persona = p_cod_persona;
       delete SB_CLIENTES where cod_persona = p_cod_persona;
       delete SB_FDG_PERSONAS where cod_persona = p_cod_persona;
       delete SB_ITEMS_DET where cod_persona = p_cod_persona;
       delete SB_PERSONAS_CRC_DET where cod_persona = p_cod_persona;
       delete SB_TMP_CRC where cod_persona = p_cod_persona;
       --las de extracto sin restricción
       delete GE_EXT_CLI_MOVIMIENTOS where cod_persona = p_cod_persona;
       delete GE_EXT_RESUMENES where cod_persona = p_cod_persona;
       delete GE_EXT_CLI_CUENTAS where cod_persona = p_cod_persona;
       delete GE_EXT_CLIENTES where cod_persona = p_cod_persona;
       --las de CRM
       delete CR_PER_AFICIONES where cod_persona = p_cod_persona;
       delete CR_PER_CELEBRACIONES where cod_persona = p_cod_persona;
       delete CR_PER_CLUBES where cod_persona = p_cod_persona;
       delete CR_PER_DEUDAS where cod_persona = p_cod_persona;
       delete CR_PER_ING_EGRESOS where cod_persona = p_cod_persona;
       delete CR_PER_NOTAS where cod_persona = p_cod_persona;
       delete CR_PER_PROPIEDADES where cod_persona = p_cod_persona;
       delete CR_PUN_PERSONAS where cod_persona = p_cod_persona;
       delete CR_PER_PUNTAJES where cod_persona = p_cod_persona;
       delete CR_RECLAMOS where cod_persona = p_cod_persona;
       delete CR_PER_VEHICULOS where cod_persona = p_cod_persona;
       delete CR_ATENCIONES where cod_persona = p_cod_persona;
       delete CR_CAM_PERSONAS where cod_persona = p_cod_persona;
       delete CR_EXP_CUENTAS where cod_persona = p_cod_persona;
       delete CR_EXP_CLIENTES where cod_persona = p_cod_persona;
       delete CR_REF_COMERCIALES where cod_persona = p_cod_persona;
       delete CR_REF_PERSONALES where cod_persona = p_cod_persona;
       delete CR_INF_LABORALES where cod_persona = p_cod_persona;
       delete CR_PEDIDOS where cod_persona = p_cod_persona;
       delete CR_INF_FONDOS where cod_persona = p_cod_persona;
       delete CR_ACT_ESPERADAS where cod_persona = p_cod_persona;
       delete CR_PER_TIP_OPERACIONES where cod_persona = p_cod_persona;
       delete CR_SOLICITUDES where cod_persona = p_cod_persona;
       delete CR_PER_TIP_OPERACIONES where cod_persona = p_cod_persona;
       delete CR_PER_TIP_OPERACIONES_HIS where cod_persona = p_cod_persona;
       -- borrado de agendas
       delete CR_AGENDAS where cod_persona = p_cod_persona;
       --datos generales
       delete GE_CLA_OPERACIONES where cod_persona = p_cod_persona;
       delete GE_CLA_OPERACIONES_HIS where cod_persona = p_cod_persona;
       delete GE_DIR_ENVIOS where cod_persona = p_cod_persona;
       delete GE_MSJ_BCA_ELE where cod_persona = p_cod_persona;
       delete GE_NIV_ENDEUDAMIENTO where cod_persona = p_cod_persona;
       delete GE_SOL_VER_LABORALES where cod_persona = p_cod_persona;
       delete GE_SOL_VER_PARTICULARES where cod_persona = p_cod_persona;
       delete TA_SOL_ADICIONALES where cod_persona = p_cod_persona;
       delete TA_TARJETAS where cod_persona = p_cod_persona;
       --tablas base
       delete BA_DIRECCIONES where cod_persona = p_cod_persona;
       delete BA_TELEFONOS where cod_persona = p_cod_persona;
       delete BA_PER_FISICAS where cod_persona = p_cod_persona;
       delete BA_PER_JURIDICAS where cod_persona = p_cod_persona;
       delete BA_PER_DAT_ADICIONALES where cod_persona= p_cod_persona;
       --DYDMR-1517
       delete BA_PER_VALIDACIONES where cod_persona= p_cod_persona;
       delete BA_MAILS where cod_persona= p_cod_persona;
       delete BA_PER_FATCA where cod_persona= p_cod_persona;
       ---MDP-CON_ ARC_REC_BAN
       delete BA_PER_DOCUMENTOS where cod_persona= p_cod_persona;
       --Acción al portador
       delete from ba_acc_portador where cod_persona = p_cod_persona;
       delete from ba_per_dat_adicionales d where exists (select 1 from ba_vinculos v
                                                           where v.cod_persona = p_cod_persona
                                                             and d.parametro = 'POR_PARTICIPACION:'||v.TIPO||v.cod_persona);
       delete from ba_per_dat_adicionales p
        where p.parametro = 'ACC_PORTADOR:'||p_cod_persona;
       
       --se inserta en la tabla antes de eliminar
       LP_INS_PER_ELIMINADA(p_cod_persona, p_observacion);
       --borrar master
       delete BA_PERSONAS where cod_persona = p_cod_persona;
    exception
       when others then
          rollback;
          raise_application_error(-20222,sqlerrm);
   end;
end;
/

