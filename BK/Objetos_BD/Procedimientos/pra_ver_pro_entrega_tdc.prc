create or replace procedure it.PRA_VER_PRO_ENTREGA_TDC(P_MSJ_PROCESO out varchar2) is

   --Variables--
   V_FECHA             date;
   V_HORA              varchar2(8);
   V_EST_LOTE          varchar2(1);
   V_EST_REGISTRO      varchar2(1);
   V_COD_MODALIDAD     AH_CTA_VISTAS.COD_MODALIDAD%type;
   V_MSJ_DET_ERROR     varchar2(4000);
   V_MSJ_DET_ERROR_AUX varchar2(4000);
   V_FEC_VENCIMIENTO   date;
   V_EXI_PERSONA       varchar2(1);
   V_EXI_ADHERENTE     varchar2(1);
   V_TIP_TAR_REN       AH_TAR_DEBITOS.TIP_TAR_DEBITO%type;
   V_NRO_LOTE          number(6);
   V_CAN_REG_LOTE      number(6);
   V_CAN_REG_ERROR     number(6);
   V_RET_CARRO         varchar2(500) := '**';
   V_IDE_REGISTRO      AH_TAR_DEB_MASIVO_TMP.IDE_REG_LOTE%type;
   V_CAN_PRO_LOTE      number(6);
   V_CAN_NOR_LOTE      number(6);
   V_CAN_ERR_LOTE      number(6);
   V_MENSAJE           varchar2(4000);
   V_MEN_AUX           varchar2(4000);
   V_EST_CUENTA        GE_EST_CUENTAS.ESTADO%type;
   V_LUGAR             varchar2(4000);
   V_TIE_ERR_LOTE      varchar2(1);
   V_EXI_TARJETA       varchar2(1);
   -------
   --Cursores--
   cursor C_ENT_TAR_TDC_MASIVO is
   
      select T.*
            ,T.ROWID REGISTRO
        from TA_TAR_ENT_MASIVO_TMP T
       where T.USU_INSERCION = user
       order by T.ROWID;
begin
   V_LUGAR := 'Inicio de variables';
   --Variables generales--
   V_FECHA         := PAG_CAL.FU_OBT_FEC_ACTUAL(3);
   V_HORA          := TO_CHAR(sysdate, 'HH24:MI:SS');
   V_CAN_REG_ERROR := 0;
   V_EST_LOTE      := 'P';

   --se elimina los espacios en blanco si es que los hay de la columna nro tarjeta
   begin
      update TA_TAR_ENT_MASIVO_TMP T
         set T.NRO_TARJETA = substr(t.nro_tarjeta,0,16)
       where T.USU_INSERCION = user;
   exception
      when others then
         V_MSJ_DET_ERROR_AUX := 'error al verificar espacios en blanco de nro de tarjeta: ' ||                       sqlerrm;
   end;
   
   if V_MSJ_DET_ERROR_AUX is not null then
      V_MSJ_DET_ERROR := SUBSTR(V_MSJ_DET_ERROR_AUX, 1, 4000);
   end if;
   --Verificar datos importados--
   V_CAN_REG_LOTE := 0;
   for DET in C_ENT_TAR_TDC_MASIVO loop
      V_LUGAR := 'Inicio de variables dentro del cursor de tarjetas';
      --Inicializar variables--
      V_EST_REGISTRO    := 'N'; --Insertado--
      V_COD_MODALIDAD   := null;
      V_MSJ_DET_ERROR   := null;
      V_FEC_VENCIMIENTO := null;
      V_EXI_PERSONA     := null;
      V_EXI_ADHERENTE   := null;
      V_TIP_TAR_REN     := null;
      V_IDE_REGISTRO    := null;
      V_EST_CUENTA      := null;
      V_CAN_REG_LOTE    := NVL(V_CAN_REG_LOTE, 0) + 1;
   
      --Validacion de cuenta--
      V_MSJ_DET_ERROR_AUX := null;
      begin
         select X.ESTADO
               ,X.COD_MODALIDAD
           into V_EST_CUENTA
               ,V_COD_MODALIDAD
           from GE_CUENTAS X
          where X.NRO_CUENTA = DET.NRO_CUENTA;
      exception
         when NO_DATA_FOUND then
            V_MSJ_DET_ERROR_AUX := 'Cta. no existe ' || DET.NRO_CUENTA || V_RET_CARRO;
         when others then
            V_MSJ_DET_ERROR_AUX := SUBSTR('Cta. ' || DET.NRO_CUENTA || ' con error: ' ||
                                          sqlerrm,
                                          1,
                                          2000) || V_RET_CARRO;
      end;
      if V_MSJ_DET_ERROR_AUX is not null then
         V_MSJ_DET_ERROR := SUBSTR(V_MSJ_DET_ERROR_AUX, 1, 4000);
      end if;
      --Verificacion de estado de cuenta--
      V_MSJ_DET_ERROR_AUX := null;
      if NVL(V_EST_CUENTA, 'X') = 'C' then
         --Cta. cancelada--
         V_MSJ_DET_ERROR_AUX := 'Cta. Cancelada ' || DET.NRO_CUENTA || V_RET_CARRO;
      end if;
      if V_MSJ_DET_ERROR_AUX is not null then
         V_MSJ_DET_ERROR := SUBSTR(V_MSJ_DET_ERROR_AUX, 1, 4000);
      end if;
   
      --Validacion de Cod. Persona--
      if DET.COD_PERSONA is not null then
         V_MSJ_DET_ERROR_AUX := null;
         select DECODE(NVL(count(*), 0), 0, 'N', 'S')
           into V_EXI_PERSONA
           from BA_PERSONAS X
          where X.COD_PERSONA = DET.COD_PERSONA;
         if NVL(V_EXI_PERSONA, 'N') = 'N' then
            V_MSJ_DET_ERROR_AUX := 'Cliente no existe ' || DET.COD_PERSONA || V_RET_CARRO;
         end if;
         if V_MSJ_DET_ERROR_AUX is not null then
            V_MSJ_DET_ERROR := SUBSTR(V_MSJ_DET_ERROR || V_MSJ_DET_ERROR_AUX, 1, 4000);
         end if;
      end if;
      --valida existencia de tarjeta
      begin
         select 'S'
           into V_EXI_TARJETA
           from TA_TARJETAS T
          where T.NRO_CUENTA = DET.NRO_CUENTA
            and T.NRO_TARJETA = DET.NRO_TARJETA
            and ROWNUM = 1;
      exception
         when NO_DATA_FOUND then
            V_EXI_TARJETA       := 'N';
            V_MSJ_DET_ERROR_AUX := 'NO existe el nro de tarjeta para la cta relacionada.';
         when others then
            V_MSJ_DET_ERROR_AUX := 'error al verificar existencia de tarjeta en ITGF' ||
                                   sqlerrm;
      end;
   
      if V_MSJ_DET_ERROR_AUX is not null then
         V_MSJ_DET_ERROR := SUBSTR(V_MSJ_DET_ERROR || V_MSJ_DET_ERROR_AUX, 1, 4000);
      end if;
   
      --Actualizar el registro--
      if V_MSJ_DET_ERROR is not null then
         V_EST_REGISTRO  := 'E';
         V_CAN_REG_ERROR := NVL(V_CAN_REG_ERROR, 0) + 1;
         V_MSJ_DET_ERROR := SUBSTR('Validac.-Nro.Reg.:' || TO_CHAR(V_CAN_REG_LOTE) ||
                                   V_RET_CARRO || V_MSJ_DET_ERROR,
                                   1,
                                   4000);
      end if;
      --Obtener el Identificador del Registro--
      --Traer Nro. de Lote--
      select S_IDE_REG_PRO_TDCENT.NEXTVAL
        into V_IDE_REGISTRO
        from DUAL;
   
      update TA_TAR_ENT_MASIVO_TMP Y
         set Y.EST_REGISTRO   = V_EST_REGISTRO
            ,Y.MSJ_RESPUESTAS = V_MSJ_DET_ERROR
            ,Y.NRO_REGISTRO   = V_CAN_REG_LOTE
       where Y.ROWID = DET.REGISTRO;
   end loop;

   --Traer Nro. de Lote--
   select S_NRO_LOT_PRO_TDCENT.NEXTVAL
     into V_NRO_LOTE
     from DUAL;
   if V_CAN_REG_ERROR = V_CAN_REG_LOTE then
      V_EST_LOTE := 'E';
   end if;
   --Actualizar nro de Lote--
   update TA_TAR_ENT_MASIVO_TMP Y
      set Y.NRO_LOTE     = V_NRO_LOTE
         ,Y.EST_LOTE     = V_EST_LOTE
         , --Procesado--
          Y.FEC_PRO_LOTE = V_FECHA
         ,Y.HOR_PRO_LOTE = V_HORA
    where Y.USU_INSERCION = user;

   --Insertar tabla normal--
   insert into TA_TAR_ENT_MASIVO
      select X.*
        from TA_TAR_ENT_MASIVO_TMP X
       where X.NRO_LOTE = V_NRO_LOTE;

   V_CAN_PRO_LOTE := 0;
   V_CAN_NOR_LOTE := 0;
   V_CAN_ERR_LOTE := 0;
   select NVL(count(*), 0)
         ,sum(DECODE(X.EST_REGISTRO, 'N', 1, 0))
         ,sum(DECODE(X.EST_REGISTRO, 'E', 1, 0))
     into V_CAN_PRO_LOTE
         ,V_CAN_NOR_LOTE
         ,V_CAN_ERR_LOTE
     from TA_TAR_ENT_MASIVO X
    where X.NRO_LOTE = V_NRO_LOTE;

   -- DETALLE DE MENSAJE A DESPLEGAR
   begin
      select '**Resumen Lote: ' || TO_CHAR(V_NRO_LOTE) || ' - ' || 'Archivo: ' || A.ARCHIVO || '**' ||
             CHR(10) LINEA
        into V_MEN_AUX
        from GE_ARCHIVOS A
       where A.REFERENCIA = 'PRO_TDC_ENTREGA';
   
      V_MENSAJE := V_MENSAJE || V_MEN_AUX;
   
      select 'Procesados: ' || TO_CHAR(NVL(count(*), 0)) || ' - ' || 'Correctos: ' ||
             TO_CHAR(NVL(sum(DECODE(A.EST_REGISTRO, 'N', 1, 0)), 0)) || ' - ' ||
             'Con Error: ' || TO_CHAR(NVL(sum(DECODE(A.EST_REGISTRO, 'E', 1, 0)), 0)) ||
             CHR(10) LINEA
        into V_MEN_AUX
        from TA_TAR_ENT_MASIVO A
       where A.NRO_LOTE = V_NRO_LOTE;
   
      V_MENSAJE := V_MENSAJE || V_MEN_AUX;
   
      select DECODE(NVL(count(*), 0), 0, 'N', 'S')
        into V_TIE_ERR_LOTE
        from TA_TAR_ENT_MASIVO A
       where A.NRO_LOTE = V_NRO_LOTE
         and A.EST_REGISTRO = 'E';
   
      select DECODE(V_TIE_ERR_LOTE,
                    'S',
                    '*Verificar detalle del error en consulta dinámica: TDCENT - INVENTARIO ENTREGAS DE TDC',
                    'Lote ' || TO_CHAR(V_NRO_LOTE) || ' sin Errores de validacion' ||
                    CHR(10) ||
                    'Verificar detalle del proceso en consulta dinámica TDCENT - INVENTARIO ENTREGAS DE TDC') LINEA
        into V_MEN_AUX
        from DUAL;
   
      V_MENSAJE := V_MENSAJE || V_MEN_AUX;
   
   end;
   --Cargar mensaje de retorno--
   P_MSJ_PROCESO := V_MENSAJE;
exception
   when others then
      RAISE_APPLICATION_ERROR(-20001,
                              'Error en ' || V_LUGAR || ' PRA_VER_PRO_ENTREGA_TDC: ' ||
                              sqlerrm);
end;
/

