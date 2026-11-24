CREATE OR REPLACE PROCEDURE IT.PRA_ELI_PINES_TDD  is
   v_can_dia ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('CAN_DIA_BOR_PINES');
BEGIN

   update ah_tar_deb_pines t set t.nro_pin = null,
                                 t.pin_encriptado = null,
                                 t.estado = null
   where pag_cal.FU_OBT_FEC_ACTUAL(1) - nvl(t.fec_impresion,trunc(t.fec_modificacion)) >= v_can_dia;

exception
when others then
   RAISE_APPLICATION_ERROR(-20001,'Error al actualizar pines de TDD con más de '||v_can_dia||' días de impresión :'||sqlerrm);
end PRA_ELI_PINES_TDD;
/

