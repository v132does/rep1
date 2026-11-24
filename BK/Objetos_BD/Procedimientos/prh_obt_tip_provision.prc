CREATE OR REPLACE PROCEDURE IT.PRH_OBT_TIP_PROVISION
 (P_COD_TIP_PROVISION IN RH_TIP_PROVISIONES.COD_TIP_PROVISION%TYPE
 ,RP_TIP_PROVISION IN OUT RH_TIP_PROVISIONES%ROWTYPE
 )
 IS
BEGIN
   SELECT *
   INTO rp_tip_provision
   FROM rh_tip_provisiones
   WHERE cod_tip_provision = p_cod_tip_provision;
EXCEPTION
   WHEN NO_DATA_FOUND THEN
      raise_application_error(-20000,
      'No existe tipo de Provisión '||to_char(p_cod_tip_provision));
   WHEN OTHERS THEN
      raise_application_error(-20000,
      'Rec.Tip.Prov. '||to_char(p_cod_tip_provision)||' '||sqlerrm);
END;
/

