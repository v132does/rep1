CREATE OR REPLACE PROCEDURE IT.PRG_CAN_CIR_SNP
IS
/*Cancela los circuitos de SNP,
que quedaron sin finalizarce de dias anteriores--*/

v_fec_actual date:= pag_cal.FU_OBT_FEC_ACTUAL(1);
BEGIN
    begin pre_ini_aplicacion; pae_cnf.g_cod_modulo:=1; end;
    
    UPDATE wf_circuitos a
       SET A.ESTADO='C'
     WHERE trunc(a.fec_insercion) < trunc(v_fec_actual)
       and a.estado not in ('C','F')
	     and a.cod_tip_circuito in (1, 902, 903, 922, 911, 102, 103, 111, 202, 203, 204);
  
END;
/

