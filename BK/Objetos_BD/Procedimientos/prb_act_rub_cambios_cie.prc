CREATE OR REPLACE PROCEDURE IT.prb_act_rub_cambios_cie IS
BEGIN
   UPDATE cie_cb_sal_oficinas t
      SET sal_equ_loc_ant = t.sal_mon_loc_ant,
          deb_equ_local   = t.deb_mon_local,
          cre_equ_local   = t.cre_mon_local
    WHERE substr(cod_rubro, 14, 2) = '98';
END prb_act_rub_cambios_cie;
/

