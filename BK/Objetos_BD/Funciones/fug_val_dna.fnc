CREATE OR REPLACE FUNCTION IT.FUG_VAL_DNA
            (P1 in varchar2, --accion a ejecutar
             P2 in varchar2, --cajero
             P3 in varchar2, --identificador de la operacion
             P4 in varchar2, --tipo de operacion
             P5 in varchar2, --idBroker(importador)   vjo--idTrader (despachante)
             P6 in varchar2, --idTrader (despachante) vjo--idBroker (importador)
             P7 in number,   --importe
             P8 in varchar2) --usuario de conexion
  return varchar2 is

  PRAGMA AUTONOMOUS_TRANSACTION;

  vestado         varchar2(1);
  valor_retorno   varchar2(500);
  vcodigoerror    varchar2(2);
  vstatus         varchar(1);
  vid             number(10);
  vtipooperacion  varchar2(1);
  vpersonas       varchar2(350);
  vidBroker       varchar2(100);
  vidTrader       varchar2(100);

begin

  -- No se va Ñ a la DNA se reemplaza por la /(barra)
  vidBroker := replace(p5,'Ñ','\');
  vidTrader := replace(p6,'Ñ','\');

  -- Id clave a Grabar, llave del archivo
  select s_dna_log.NEXTVAL
    into vid
    from dual;

  -- Identificar el tipo de Accion a realizar
  if p1='CrearDeposito' then
     vtipooperacion:='C';
  else
     if p1='ValidarRuc' then
        vtipooperacion:='R';
     else
        return '98-Error Tipo de Accion no definida, Accion: '||p1;
     end if;
  end if;

  begin
    -- Inserto para que el programa del Web service tome los datos
    insert into ge_dna_log
      (id, idbroker, idtrader, monto, tipo, fechaoperacion, fechainserccion,
      usuario, estado, idcajero, iddepositobanco, tipooperacion)
    values
      (vid, vidBroker, vidTrader, p7, p4, sysdate, sysdate,
       p8, 'P', p2, p3, vtipooperacion);
    commit;

    -- Espera que se confirme el registro en la aduana
    vestado:='P';
    WHILE vestado = 'P' LOOP
      select estado
        into vestado
        from ge_dna_log
       where id = vid;
    END LOOP;

    --recuperar el codigo de error enviado por la DNA
    begin
      select codigoerror, status, '#'||substr(brokername,1,50)||'#'||substr(tradername,1,50)
        into vcodigoerror, vstatus, vpersonas
        from ge_dna_log
       where id = vid;
    exception
      when no_data_found then
        return '98-Error No existe el registro grabado para la DNA, id: '||to_char(vid);
    end;

    -- Busco el error si es que existe
    begin
      select codigo||'-'||mensaje
        into valor_retorno
        from ge_dna_cod_error
       where codigo = vcodigoerror;
    exception
      when no_data_found then
        return '98-Error NO existe en la Tabla de errores de la DNA, Codigo: '|| vcodigoerror;
    end;

    valor_retorno:=valor_retorno||vpersonas;

    if vstatus='S' and vcodigoerror in ('00','02') then
        valor_retorno:='00-Transaccion Aceptada'||vpersonas;
    end if;

    return valor_retorno;

  exception
    when no_data_found then
      return '98-No existen datos';
    when others then
      return sqlcode ||sqlerrm ;
  end ;

end FUG_VAL_DNA;
/

