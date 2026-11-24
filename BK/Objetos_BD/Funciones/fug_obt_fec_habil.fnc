CREATE OR REPLACE FUNCTION IT.FUG_OBT_FEC_HABIL(P_FECHA IN DATE, P_CAN_DIAS NUMBER) RETURN DATE
 IS
  v_fecha date;
BEGIN
  v_fecha := p_fecha;
  FOR I in 1..P_CAN_DIAS LOOP
      v_fecha := v_fecha + 1;
      v_fecha := pag_cal.fu_obt_fec_habil(v_fecha,1,7);
  END LOOP;
   return v_fecha;
EXCEPTION
  WHEN OTHERS THEN
     raise_application_error(20000, 'error'||sqlerrm);
END;
/

