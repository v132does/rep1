create or replace function it.FUG_OBT_VAL_PARAMETRO(P_COD_MODULO        IN VARCHAR2, --- Código del módulo
                                                 P_COD_MODALIDAD     IN VARCHAR2, --- Código de la modalidad
                                                 P_COD_SUB_MODALIDAD IN NUMBER DEFAULT NULL, --- Código de la sub-modalidad
                                                 P_COD_PAQUETE       IN NUMBER, --- Código del paquete
                                                 P_COD_MONEDA        IN VARCHAR2, --- Código de la moneda del paquete
                                                 P_COD_AFINIDAD      IN NUMBER DEFAULT NULL, --- Código de la afinidad
                                                 P_COD_SUB_AFINIDAD  IN NUMBER DEFAULT NULL) --- Código de la sub-afinidad
 return number is
  v_val_parametro number; -- valor del parámetro

begin
  -- Busco el valor del parámetro
  SELECT GPD.VAL_PARAMETRO
    INTO v_val_parametro
    from GE_PAQ_MODALIDADES GPM, GE_PAR_DINAMICOS GPD
   WHERE GPM.COD_MODULO = GPD.COD_MODULO
     AND GPM.COD_MODALIDAD = GPD.COD_MODALIDAD
     AND NVL(GPM.COD_SUB_MODALIDAD, '0') = NVL(GPD.COD_SUB_MODALIDAD, '0')
     AND GPD.PARAMETRO = 'CAN_PRO_PAQUETE'
     AND GPM.COD_MODULO = P_COD_MODULO
     AND GPM.COD_MODALIDAD = P_COD_MODALIDAD
     AND NVL(GPM.COD_SUB_MODALIDAD, -1) = P_COD_SUB_MODALIDAD
     AND GPM.COD_PAQUETE = P_COD_PAQUETE
     AND NVL(GPM.AFINIDAD, -1) = P_COD_AFINIDAD
     AND NVL(GPM.SUB_AFINIDAD, -1) = P_COD_SUB_AFINIDAD
     AND NVL(GPD.COD_MONEDA, 'GS') = P_COD_MONEDA;
  return v_val_parametro;
exception
  when no_data_found then
    return 0;
end FUG_OBT_VAL_PARAMETRO;
/

