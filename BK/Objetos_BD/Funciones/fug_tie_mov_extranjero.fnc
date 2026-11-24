create or replace function it.FUG_TIE_MOV_EXTRANJERO(P_NRO_CUENTA    in GE_CUENTAS.NRO_CUENTA%type
                                                 ,P_COD_MODALIDAD in GE_CUENTAS.COD_MODALIDAD%type
                                                 ,P_MESES         in number DEFAULT -12)
   return varchar2 is
   V_TIE_MOVIMIENTO varchar2(2) := 'N';
begin

   if P_COD_MODALIDAD = 31 then
      --ahorro
      begin
         select A.MOV_EXT
           into V_TIE_MOVIMIENTO
           from (select 'S' MOV_EXT
                   from AH_MOVIMIENTOS_HIS T
                  where T.NRO_CUENTA = P_NRO_CUENTA
                    and T.COD_TRA_PADRE in 375 -- extraccion en atm extranjero
                    and T.COD_MONEDA != 'GS'
                    and TRUNC(T.FECHA) >= TRUNC(ADD_MONTHS(sysdate, P_MESES)) --un año atrás
                 union all
                 select 'S' MOV_EXT
                   from AH_MOVIMIENTOS_HIS T
                  where T.NRO_CUENTA = P_NRO_CUENTA
                    and T.COD_TRA_PADRE = 374 -- compra en pos extranjero
                    and T.COD_MONEDA != 'GS'
                    and TRUNC(T.FECHA) >= TRUNC(ADD_MONTHS(sysdate, P_MESES)) --un año atrás
                 union all
                 select 'S' MOV_EXT
                   from AH_MOVIMIENTOS_HIS T
                  where T.NRO_CUENTA = P_NRO_CUENTA
                    and T.COD_TRA_PADRE = 377 -- transf saldo extranjero
                    and T.COD_MONEDA != 'GS'
                    and TRUNC(T.FECHA) >= TRUNC(ADD_MONTHS(sysdate, P_MESES))) A --un año atrás
          where ROWNUM = 1;
      exception
         when NO_DATA_FOUND then
            null;
         when others then
            RAISE_APPLICATION_ERROR(-20000,
                                    'Error al obtener movimientos históricos del exterior:' ||
                                    sqlerrm);
      end;
   elsif P_COD_MODALIDAD = 41 then
      --cta cte
      --
      begin
         select A.MOV_EXT
           into V_TIE_MOVIMIENTO
           from (select 'S' MOV_EXT
                   from CC_MOVIMIENTOS_HIS T
                  where T.NRO_CUENTA = P_NRO_CUENTA
                    and T.COD_TRA_PADRE in 375 -- extraccion en atm extranjero
                    and T.COD_MONEDA != 'GS'
                    and TRUNC(T.FECHA) >= TRUNC(ADD_MONTHS(sysdate, P_MESES)) --un año atrás
                 union all
                 select 'S' MOV_EXT
                   from CC_MOVIMIENTOS_HIS T
                  where T.NRO_CUENTA = P_NRO_CUENTA
                    and T.COD_TRA_PADRE = 374 -- compra en pos extranjero
                    and T.COD_MONEDA != 'GS'
                    and TRUNC(T.FECHA) >= TRUNC(ADD_MONTHS(sysdate, P_MESES)) --un año atrás
                 union all
                 select 'S' MOV_EXT
                   from CC_MOVIMIENTOS_HIS T
                  where T.NRO_CUENTA = P_NRO_CUENTA
                    and T.COD_TRA_PADRE = 377 -- transf saldo extranjero
                    and T.COD_MONEDA != 'GS'
                    and TRUNC(T.FECHA) >= TRUNC(ADD_MONTHS(sysdate, P_MESES))) A --un año atrás
          where ROWNUM = 1;
      exception
         when NO_DATA_FOUND then
            null;
         when others then
            RAISE_APPLICATION_ERROR(-20000,
                                    'Error al obtener movimientos históricos del exterior:' ||
                                    sqlerrm);
      end;
   end if;

   return V_TIE_MOVIMIENTO;
end;
/

