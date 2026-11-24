create or replace procedure it.prl_control_planilla
is
   /************************************************************/
   /*	 Nombre: PRL_CONTROL_PLANILLA	  		  									 */
   /*	 Hecho Por: Lic. Julio Cesar Leguizamon G.  					   */
   /*	 Fecha: 22/11/2006                          					   */
   /*	 Objetivo: Controla la consistencia de la planilla de 	 */
	 /*  poscion de cambios con respecto a los movimeintos       */
   /************************************************************/

v_moneda						lc_posiciones.cod_moneda%type;
v_cod_tip_ope_bcp		lc_posiciones.cod_tip_ope_bcp%type;

cursor mov is
select cod_mad_padre, afe_posicion, a.cod_bco_central, cod_moneda, sum(monto) monto
from lc_tip_operaciones, ge_movimientos a
where estado = 'N'
and cod_moneda <> pag_gen.fu_obt_mon_local
and cod_tip_ope_cambio = cod_tip_operacion
and reversado = 'N'
and nro_secuencia = 1
and afe_posicion in ('E','O')
GROUP by cod_mad_padre, afe_posicion, cod_moneda, a.cod_bco_central;

cursor posicion is
select cod_moneda, cod_tip_ope_bcp, mto_com_efe_act, 
			 mto_com_nef_act, mto_vta_efe_act, mto_vta_nef_act 
from lc_posiciones
where cod_moneda = v_moneda
and cod_tip_ope_bcp = v_cod_tip_ope_bcp;

begin
   for reg in mov loop
   		v_moneda						:= reg.cod_moneda;
    	v_cod_tip_ope_bcp		:= reg.cod_bco_central;
      for reg1 in posicion loop
					if reg.cod_mad_padre = 71 then--ES COMPRA
						 if reg.afe_posicion = 'E' then--ES EFECTIVO
						 		if reg.monto <> reg1.mto_com_efe_act then
                  raise_application_error(-20000,'No coincide...COMPRA EFECTIVO, Moneda: '||reg.cod_moneda||' '||reg.cod_bco_central);
								end if;
						 else--NO EFECTIVO (O)
						 		if reg.monto <> reg1.mto_com_nef_act then
                  raise_application_error(-20000,'No coincide...COMPRA NO EFECTIVO, Moneda: '||reg.cod_moneda||' '||reg.cod_bco_central);
								end if;
						 end if;
					else--ES VENTA (72)
						 if reg.afe_posicion = 'E' then--ES EFECTIVO
						 		if reg.monto <> reg1.mto_vta_efe_act then
                  raise_application_error(-20000,'No coincide...VENTA EFECTIVO, Moneda: '||reg.cod_moneda||' '||reg.cod_bco_central);
								end if;
						 else--NO EFECTIVO (O
						 		if reg.monto <> reg1.mto_vta_nef_act then
                  raise_application_error(-20000,'No coincide...VENTA NO EFECTIVO, Moneda: '||reg.cod_moneda||' '||reg.cod_bco_central);
								end if;						 
						 end if;					
					end if;
      end loop;
   end loop;
end;
/

