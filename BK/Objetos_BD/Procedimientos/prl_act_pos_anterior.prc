CREATE OR REPLACE PROCEDURE IT.PRL_ACT_POS_ANTERIOR
(p_cod_ofi_cambio in lc_sal_diarios.cod_oficina%type, 
 p_cod_moneda  in lc_sal_diarios.cod_moneda%type,
 p_pos_com_efectivo in lc_sal_diarios.mto_pos_com_efe_ant%type,    --compra efectivo
 p_pos_com_no_efectivo in lc_sal_diarios.mto_pos_com_nef_ant%type, --compra no efectivo
 p_pos_vta_efectivo in lc_sal_diarios.mto_pos_vta_efe_ant%type,    --venta efectivo         
 p_pos_vta_no_efectivo in lc_sal_diarios.mto_pos_vta_nef_ant%type  --venta no efectivo
)
IS
/*Inicializa o actualiza la posición, por oficina de cambio y moneda*/
BEGIN
    update lc_sal_diarios
       set mto_pos_com_efe_ant = nvl(p_pos_com_efectivo, 0),
	         mto_pos_com_nef_ant = nvl(p_pos_com_no_efectivo, 0),
           mto_pos_vta_efe_ant = nvl(p_pos_vta_efectivo, 0),
           mto_pos_vta_nef_ant = nvl(p_pos_vta_no_efectivo, 0)
     where cod_moneda   = p_cod_moneda
       and cod_oficina  = p_cod_ofi_cambio;

       If sql%notfound then
         --insertar la posición
         insert into lc_sal_diarios
             (cod_oficina, cod_moneda, fecha,
             mto_pos_com_efe_ant, mto_pos_com_nef_ant,
             mto_pos_vta_efe_ant, mto_pos_vta_nef_ant)
         values
             (p_cod_ofi_cambio, p_cod_moneda, pag_cal.FU_OBT_FEC_ACTUAL(7),
              nvl(p_pos_com_efectivo,0), nvl(p_pos_com_no_efectivo,0),
             nvl(p_pos_vta_efectivo,0), nvl(p_pos_vta_no_efectivo,0));
       end if;
       --
       prl_gen_sal_posiciones;
exception
  WHEN OTHERS THEN
     RAISE_APPLICATION_ERROR(-20000,'Sal.Diarios. Ofi.'||p_cod_ofi_cambio||'-'||p_cod_moneda||'-'||SQLERRM);
END;
/

