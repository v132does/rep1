create or replace procedure IT.PRG_GEN_ARC_RETENCIONES (p_fecha date default null) IS

BEGIN
   PRA_GEN_RET_VIRTUAL(p_fecha);
   PRG_GEN_RET_VIRTUAL(p_fecha);
   PRG_GEN_RET_SER_DIGITAL(p_fecha);
END;

