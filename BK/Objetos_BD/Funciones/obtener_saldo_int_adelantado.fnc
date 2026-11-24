CREATE OR REPLACE FUNCTION IT.OBTENER_SALDO_INT_ADELANTADO (p_nuries number, p_sucursal number, p_propuesta number, p_congru varchar2,
                                                                          p_modalidad varchar2, p_ade_venc varchar2)
return number
is
   v_int_maecartera number(18,5):=0;
   v_int_maeicpc  number(18,5)  :=0;
   v_saldo_int number(18,5)  :=0;
begin

     --Si el préstamo es Francés, el interés es vencido,por tanto el
     --SALDO DE INTERES ADELANTADO es 0
     if(trim(p_modalidad) = 'F' and
             substr(trim(p_congru),1,3) not in ('141','405','351')) then--Por si acaso se controla que no sea ninguno
          return 0;                                                     --de los préstamos de tipo descuento
       end if;


     --Si es un descuento de cheques o descuento de documentos, en teoría todo el interés es adelantado
     if(substr(trim(p_congru),1,3)='141' --Dcto de documentos sector financiero
          or substr(trim(p_congru),1,3)='405' --Dcto de cheques sector no financiero
             or  substr(trim(p_congru),1,3)='351') then --Dcto de cheques sector no financiero

            --Según RG todo lo que está en MAECARTERA a excepción de los préstamos
            --del sistema francés tienen interés ADELANTADO
           /* select nvl(sum(iadinteres),0) into v_int_maecartera
                   from maeact_maecartera mc where mc.nuries = p_nuries and mc.sucursalfu = p_sucursal
                        and mc.propuesta = p_propuesta;

            --Según RG todo lo que está en MAEICPC es VENCIDO, pero si FEINI = VTO es ADELANTADO
            select nvl(sum(interes),0) into v_int_maeicpc
                   from maeact_maeicpc mp where mp.riesgo = p_nuries and mp.sucursal = p_sucursal
                        and mp.propuesta = p_propuesta
                            and feini = vto;*/

            v_saldo_int := v_int_maecartera + v_int_maeicpc;

            -- Según RG todo lo que está en MAEICPC  y  cuyo FEINI <> VTO es VENCIDO
            -- Con esto controlamos si es que hay un descuento de cheques o descuento de documentos
            -- con intereses vencidos
       /*    select nvl(sum(interes),0) into v_int_maeicpc
                   from maeact_maeicpc mp where mp.riesgo = p_nuries and mp.sucursal = p_sucursal
                        and mp.propuesta = p_propuesta
                            and feini <> vto;*/

           /*if(v_int_maeicpc > 0) then
             registrar_fase2('Préstamo tipo DESCUENTO DE CHEQUES o DOCUMENTOS
                                  con interes VENCIDO. Riesgo: '||p_nuries||', Sucursal: '||p_sucursal
                                      ||' y Propuesta: '||p_propuesta,'PR');
           end if;*/
     end if;

     --Si el préstamo está marcado como adelantado en la Propuesta
     if(p_ade_venc = 'A') then

            --Según RG todo lo que está en MAECARTERA a excepción de los préstamos
            --del sistema francés tienen interés ADELANTADO
           /* select nvl(sum(iadinteres),0) into v_int_maecartera
                   from maeact_maecartera mc where mc.nuries = p_nuries and mc.sucursalfu = p_sucursal
                        and mc.propuesta = p_propuesta;

            --Según RG todo lo que está en MAEICPC es VENCIDO, pero si FEINI = VTO es ADELANTADO
            select nvl(sum(interes),0) into v_int_maeicpc
                   from maeact_maeicpc mp where mp.riesgo = p_nuries and mp.sucursal = p_sucursal
                        and mp.propuesta = p_propuesta
                            and feini = vto;*/

           v_saldo_int := v_int_maecartera + v_int_maeicpc;

            -- Según RG todo lo que está en MAEICPC  y  cuyo FEINI <> VTO es VENCIDO
            -- Con esto controlamos si es que hay un préstamo adelantado con intereses vencidos
       /*    select nvl(sum(interes),0) into v_int_maeicpc
                   from maeact_maeicpc mp where mp.riesgo = p_nuries and mp.sucursal = p_sucursal
                        and mp.propuesta = p_propuesta
                            and feini <> vto;*/

           /*if(v_int_maeicpc > 0) then
              registrar_fase2('Préstamo Alemán marcado con interés ADELANTADO
                                 que se guarda como VENCIDO. Riesgo: '||p_nuries||', Sucursal: '||p_sucursal
                                     ||' y Propuesta: '||p_propuesta,'PR');
           end if;*/

    /* else --El préstamo está marcado como vencido en la propuesta

            --Según RG todo lo que está en MAECARTERA a excepción de los préstamos
            --del sistema francés tienen interés ADELANTADO
            --Con esto controlamos que haya un préstao con interés vencido y que según lo indicado por el
            --Sr. Roberto se guarde como adelantado
            select nvl(sum(iadinteres),0) into v_int_maecartera
                   from maeact_maecartera mc where mc.nuries = p_nuries and mc.sucursalfu = p_sucursal
                        and mc.propuesta = p_propuesta;*/

           /*if(v_int_maecartera > 0) then
              registrar_fase2('Préstamo Alemán marcado con interés VENCIDO
                                  que se guarda como ADELANTADO. Riesgo: '||p_nuries||', Sucursal: '||p_sucursal
                                      ||' y Propuesta: '||p_propuesta,'PR');
           end if;*/

     end if;

     return v_saldo_int;
end;
/

