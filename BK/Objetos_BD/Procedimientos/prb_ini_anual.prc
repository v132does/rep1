create or replace procedure it.prb_ini_anual is
  /* inicializacion anual */
v_fec_actual     date      := pag_cal.fu_obt_fec_actual(2);
v_ano            number(4) := to_char(v_fec_actual,'yyyy');
v_mes            number(2) := to_char(v_fec_actual,'mm');
 -- verifica si es inicio de ejercicio
 FUNCTION lf_es_ini_anho
   return varchar2 is
   v_sino varchar2(1) := 'N';
   v_mes_ini_fiscal number(3);
   v_can_meses  number(4);
 BEGIN
     -- obtengo el nro actual de mes fiscal
     v_mes_ini_fiscal := fug_obt_pardinamico('MES_INI_FISCAL');
     -- obtengo la cantidad de meses del año fiscal
     v_can_meses  := fug_obt_pardinamico('CAN_MES_FISCAL');
     if v_mes = mod(v_mes_ini_fiscal+v_can_meses,12) then
        v_sino := 'S';
     end if;
     return v_sino;
 END;
begin
 if lf_es_ini_anho = 'S' then
   /* cero el ult_nro_mayor */
   UPDATE CB_RUBROS
      SET ULT_NRO_MAYOR = 0;                 -- nro de mayor de cada cuenta
   /* */
   prg_act_par_dinamico('MES_FISCAL',null, null, null, null,'1');
   prg_act_par_dinamico('ANO_FISCAL',null, null, null, null, to_number(fug_obt_pardinamico('ANO_FISCAL')) + 1);
   prg_act_par_dinamico('MES_INI_FISCAL',null, null, null, null,v_mes);
   --prg_act_par_dinamico('SIG_NRO_ASIENTO',null, null, null, null,'1'); RABP-CNF(17-07-2015)CNFACCON-1: Se comenta para que se reinicie en forma mensual
   prg_act_par_dinamico('SIG_NRO_ASI_AUTOM',null, null, null, null,'1'); --RABP-CNF(17-07-2015)CNFACCON-1: Se inserta para que se reinicie en forma anual
 end if;
end;
/

