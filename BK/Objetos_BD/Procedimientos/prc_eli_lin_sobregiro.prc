CREATE OR REPLACE PROCEDURE IT.PRC_ELI_LIN_SOBREGIRO (P_NRO_SECUENCIA IN NUMBER, P_NRO_LINEA IN NUMBER,
                                                  P_CAN_AUTOMATICA IN VARCHAR2 DEFAULT 'N') IS
   CURSOR garan IS
   SELECT cod_garantia,mto_aplicado
   FROM cc_lin_sob_garantias
   WHERE nro_secuencia = P_NRO_SECUENCIA;

   v_estado           cc_lin_sobregiros.estado%type;
   v_observ           cc_lin_sobregiros.observacion%type;
   v_usuaut           cc_lin_sobregiros.cod_usu_autoriza%type;
   v_nivel            cc_lin_sobregiros.niv_aprobacion%type;

  --Cursor de Limites pendientes de aprobación donde esta incluido una de las cuentas
   CURSOR pendiente IS
   SELECT distinct a.nro_linea
   FROM pr_lin_aplicaciones a, pr_lineas b
   WHERE b.estado = 'P'
   AND a.nro_linea = b.nro_linea
   AND a.nro_cuenta in (SELECT nro_cuenta
                        FROM cc_lin_sobregiros
                        WHERE nro_sec_padre = p_nro_secuencia);

BEGIN
/*******************************************************************************************************/
  --Agregado por Julio, cuando se elimina una linea de sobregiro que esta bajo un limite
  --pendiente de aprobacion no actualiza los montos 19/10/2005
   FOR reg IN pendiente LOOP
      FOR gar IN garan LOOP
         --Actualizar el mto aplicado de tipos de garantia por limite
         pap_gar.pr_act_tip_limite(reg.nro_linea,gar.cod_garantia,nvl(gar.mto_aplicado,0)*-1);
         --Actualizar el mto aplicado de garantias por Modalidad
         pap_gar.pr_act_mad_limite(reg.nro_linea,gar.cod_garantia,nvl(gar.mto_aplicado,0)*-1,4,41);

         UPDATE pr_lineas
             SET mto_aplicado = nvl(mto_aplicado,0) - gar.mto_aplicado
          WHERE nro_linea = reg.nro_linea;

           ---Recalcular Límite Global  
           prp_rec_apl_lim_global(reg.nro_linea,'I');

      END LOOP;
   END LOOP;

/*******************************************************************************************************/

   SELECT estado, observacion, niv_aprobacion, cod_usu_autoriza
   INTO v_estado, v_observ, v_nivel, v_usuaut
   FROM cc_lin_sobregiros
   WHERE nro_secuencia = p_nro_secuencia;
   --
   UPDATE CC_LIN_SOBREGIROS C
      SET ESTADO = v_estado,
          OBSERVACION = v_observ,
          COD_USU_AUTORIZA = v_usuaut,
          NIV_APROBACION = v_nivel
    WHERE C.NRO_SEC_PADRE = P_NRO_SECUENCIA;
   --
   PRC_INS_HIS_SOBREGIRO(P_NRO_SECUENCIA,P_CAN_AUTOMATICA);
   -- ACTUALIZO EL INDICADOR DEL ACUERDO
   UPDATE CC_CTA_CORRIENTES A
      SET ACU_SOBREGIRO = 'N'
    WHERE ACU_SOBREGIRO = 'S'
      AND EXISTS (SELECT 0 FROM CC_LIN_SOBREGIROS B
                   WHERE B.NRO_CUENTA = A.NRO_CUENTA
                     AND B.NRO_SEC_PADRE = P_NRO_SECUENCIA)
      AND NOT EXISTS (SELECT 0 FROM CC_LIN_SOBREGIROS B
                       WHERE B.NRO_CUENTA = A.NRO_CUENTA
                        AND B.NRO_SEC_PADRE <> P_NRO_SECUENCIA);
   ---
   FOR gar IN garan LOOP
     --Actualizar el mto aplicado de tipos de garantia por limite
     pap_gar.pr_act_tip_limite(p_nro_linea,gar.cod_garantia,nvl(gar.mto_aplicado,0)*-1);
     --Actualizar el mto aplicado de garantias por Modalidad
     pap_gar.pr_act_mad_limite(p_nro_linea,gar.cod_garantia,nvl(gar.mto_aplicado,0)*-1,4,41);

     UPDATE pr_lineas
         SET mto_aplicado = nvl(mto_aplicado,0) - gar.mto_aplicado
      WHERE nro_linea = p_nro_linea;

     ---Recalcular Límite Global  
       prp_rec_apl_lim_global(p_nro_linea,'I');
   END LOOP;

     -- Se cambia el orden de ejecucion debido a que corresponde borrar primeramente datos  --
   -- de las tablas hijas y posteriormente los datos de la tabla padre -- DYDMR-975 -- CN 23/09/2014 --
   BEGIN
     DELETE FROM CC_LIN_SOB_GARANTIAS C
     WHERE C.NRO_SECUENCIA = P_NRO_SECUENCIA;
   EXCEPTION
     WHEN OTHERS THEN
       raise_application_error(-20000, 'ERROR EN DELETE CC_LIN_SOB_GARANTIAS: '||
      p_nro_secuencia||' - '||SQLERRM);
   END;

   BEGIN
   DELETE FROM CC_LIN_SOBREGIROS C
   WHERE C.NRO_SEC_PADRE = P_NRO_SECUENCIA;
   EXCEPTION
     WHEN OTHERS THEN
       raise_application_error(-20000, 'ERROR EN DELETE CC_LIN_SOBREGIROS ELI NRO_SEC_PADRE: '||
      p_nro_secuencia||' - '||SQLERRM);
   END;

   BEGIN
   DELETE FROM CC_LIN_SOBREGIROS C
   WHERE C.NRO_SECUENCIA = P_NRO_SECUENCIA;
   EXCEPTION
     WHEN OTHERS THEN
       raise_application_error(-20000, 'ERROR EN DELETE CC_LIN_SOBREGIROS ELI NRO_SECUENCIA: '||
      p_nro_secuencia||' - '||SQLERRM);
   END;

   -- Recalcula el limite por si se haya estado jugando con las aplicaciones en el programa.
   If nvl(pae_cnf.G_PROGRAMA,'X') = 'CMLINSOB' and p_nro_linea is not null then
      prp_rec_apl_limite(p_nro_linea);
      prp_rec_apl_lim_global(p_nro_linea,'I');
   End If;
EXCEPTION
  WHEN OTHERS THEN
      IF SQLCODE <= -20000 THEN
         RAISE;
      ELSE
         raise_application_error(-20000, 'Error al eliminar la linea de sobregiro: '||
      p_nro_secuencia||' - '||SQLERRM);
      END IF;
END PRC_ELI_LIN_SOBREGIRO;
/
