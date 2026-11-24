create or replace function it.FUG_OBT_CAN_PAQUETE(P_COD_PERSONA       IN VARCHAR2, --- Código del módulo
                                               P_COD_MODULO        IN VARCHAR2, --- Código del módulo
                                               P_COD_MODALIDAD     IN VARCHAR2, --- Código de la modalidad
                                               P_COD_SUB_MODALIDAD IN NUMBER DEFAULT NULL, --- Código de la sub-modalidad
                                               P_COD_PAQUETE       IN NUMBER, --- Código de la moneda del paquete
                                               P_COD_AFINIDAD      IN NUMBER DEFAULT NULL, --- Código de la afinidad
                                               P_COD_SUB_AFINIDAD  IN NUMBER DEFAULT NULL) --- Código de la sub-afinidad
 return number is
  v_can_paquete number; -- cantidad del cuentas del cliente en el paquete

begin
  -- Busco el valor del parámetro
  SELECT COUNT(*)
    INTO v_can_paquete
    from GE_PAQ_MODALIDADES GPM, GE_PAQ_CUENTAS GPC
   WHERE GPM.COD_PAQUETE(+) = GPC.COD_PAQUETE
     AND GPM.COD_MODULO(+) = GPC.COD_MODULO
     AND GPM.COD_MODALIDAD(+) = GPC.COD_MODALIDAD
     AND NVL(GPM.COD_SUB_MODALIDAD(+), -1) = NVL(GPC.COD_SUB_MODALIDAD, -1)
     AND GPC.COD_PERSONA = P_COD_PERSONA
     AND GPC.COD_MODULO = P_COD_MODULO
     AND GPC.COD_MODALIDAD = P_COD_MODALIDAD
     AND NVL(GPC.COD_SUB_MODALIDAD, -1) = P_COD_SUB_MODALIDAD
     AND GPC.COD_PAQUETE = P_COD_PAQUETE
     AND NVL(GPC.AFINIDAD, -1) = P_COD_AFINIDAD
     AND NVL(GPC.SUB_AFINIDAD, -1) = P_COD_SUB_AFINIDAD;
  return v_can_paquete;
exception
  when no_data_found then
    return 0;
end FUG_OBT_CAN_PAQUETE;
/

