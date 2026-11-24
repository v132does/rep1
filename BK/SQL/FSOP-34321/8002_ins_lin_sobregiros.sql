DECLARE
  v_nro_cuenta        cc_lin_sobregiros.nro_cuenta%type;
  v_nro_sec_padre     cc_lin_sobregiros.nro_secuencia%type;
  v_nro_sec_padre_his cc_lin_sobregiros.nro_secuencia%type;
  v_nro_secuencia     cc_lin_sobregiros.nro_secuencia%type;
  v_estado            cc_lin_sobregiros.estado%type;
  v_observacion       cc_lin_sobregiros.observacion%type;
  v_insertar          varchar2(1);
  v_monto_det         number(18,2);
  v_monto_cab         number(18,2);
  v_can_automatica    varchar2(1);
  v_fec_actual        date := pag_cal.fu_obt_fec_actual(4);
  v_rowid_det         rowid;
  v_rowid_cab         rowid;
  v_tipo              cc_lin_sobregiros.tipo%type;
  v_fec_vencimiento   DATE := to_date('31/08/2024');

  --Cursor de Cuentas que recibieron crédito en la fecha y tuvieron
  --cancelación de linea anteriormente
  cursor cur_cte is
    SELECT x.nro_cuenta 
    FROM (select '900445103' nro_cuenta from dual union
    select '900607811' from dual union
    select '900569535' from dual union
    select '900654631' from dual union
    select '900655522' from dual union
    select '900518522' from dual union
    select '900616149' from dual union
    select '900576256' from dual union
    select '900642283' from dual union
    select '900626856' from dual union
    select '900559361' from dual union
    select '900648014' from dual union
    select '900651638' from dual union
    select '900516939' from dual union
    select '900613005' from dual union
    select '900616589' from dual union
    select '900437278' from dual union
    select '900655412' from dual union
    select '900628724' from dual union
    select '900564774' from dual union
    select '900330494' from dual union
    select '900074060' from dual union
    select '900636563' from dual union
    select '900616400' from dual union
    select '900544020' from dual union
    select '900638046' from dual union
    select '900515361' from dual union
    select '900500721' from dual union
    select '900651322' from dual union
    select '900651016' from dual union
    select '900627431' from dual union
    select '900578485' from dual union
    select '900304154' from dual union
    select '900653063' from dual union
    select '900636752' from dual union
    select '900646294' from dual union
    select '900479582' from dual union
    select '900515835' from dual union
    select '900652488' from dual union
    select '900641945' from dual union
    select '900653489' from dual union
    select '900654198' from dual union
    select '900580723' from dual union
    select '900655649' from dual union
    select '900530223' from dual union
    select '900655175' from dual union
    select '900653159' from dual union
    select '900621277' from dual union
    select '900624232' from dual union
    select '900481514' from dual union
    select '900654875' from dual union
    select '900403916' from dual union
    select '900633931' from dual union
    select '900654019' from dual union
    select '900653719' from dual union
    select '900553169' from dual union
    select '900503944' from dual union
    select '900486973' from dual union
    select '900143351' from dual union
    select '900630062' from dual union
    select '900559749' from dual union
    select '900297412' from dual union
    select '900654961' from dual union
    select '900655072' from dual union
    select '900515945' from dual union
    select '900560110' from dual union
    select '900601176' from dual union
    select '900580321' from dual union
    select '900654222' from dual union
    select '900518632' from dual union
    select '900440342' from dual union
    select '900602311' from dual union
    select '900632284' from dual union
    select '900654253' from dual union
    select '900607440' from dual union
    select '900639748' from dual union
    select '900535534' from dual union
    select '900636642' from dual union
    select '900612389' from dual union
    select '900588594' from dual union
    select '900486021' from dual union
    select '900432091' from dual union
    select '900653984' from dual union
    select '900600948' from dual union
    select '900655209' from dual union
    select '900278965' from dual union
    select '900647460' from dual union
    select '900563443' from dual union
    select '900049525' from dual union
    select '900628511' from dual union
    select '900642733' from dual union
    select '900653324' from dual union
    select '900654064' from dual union
    select '900654394' from dual union
    select '900652512' from dual union
    select '900634035' from dual union
    select '900541357' from dual union
    select '900628827' from dual union
    select '900633443' from dual union
    select '900630220' from dual union
    select '900547164' from dual union
    select '900655584' from dual union
    select '900631063' from dual union
    select '900169290' from dual union
    select '900069437' from dual union
    select '900017336' from dual union
    select '900501715' from dual union
    select '900654617' from dual union
    select '900653245' from dual union
    select '900208649' from dual union
    select '900203802' from dual union
    select '900205983' from dual union
    select '900119697' from dual union
    select '900005562' from dual union
    select '900362792' from dual union
    select '900007500' from dual union
    select '900257344' from dual union
    select '900190171' from dual union
    select '900653977' from dual union
    select '900524565' from dual union
    select '900506002' from dual union
    select '900652914' from dual union
    select '900049927' from dual union
    select '900544147' from dual union
    select '900553657' from dual union
    select '900534818' from dual union
    select '900654356' from dual union
    select '900282913' from dual union
    select '900550537' from dual union
    select '900421077' from dual union
    select '900287293' from dual union
    select '900576012' from dual union
    select '900614996' from dual union
    select '900515244' from dual union
    select '900150072' from dual union
    select '900641189' from dual union
    select '900607725' from dual union
    select '900653104' from dual union
    select '900653111' from dual union
    select '900653128' from dual union
    select '900606982' from dual union
    select '900337367' from dual union
    select '900461963' from dual union
    select '900580699' from dual union
    select '900598397' from dual union
    select '900527582' from dual union
    select '900502792' from dual union
    select '900064748' from dual union
    select '900636350' from dual union
    select '900197927' from dual union
    select '900454431' from dual union
    select '900655553' from dual union
    select '900484744' from dual union
    select '900653513' from dual union
    select '900072154' from dual union
    select '900519121' from dual union
    select '900652309' from dual union
    select '900164824' from dual union
    select '900653056' from dual union
    select '900606597' from dual union
    select '900351819' from dual union
    select '900654033' from dual union
    select '900541113' from dual union
    select '900052455' from dual union
    select '900653276' from dual union
    select '900615478' from dual union
    select '900630804' from dual union
    select '900502053' from dual union
    select '900525229' from dual union
    select '900653915' from dual union
    select '900552175' from dual union
    select '900552766' from dual union
    select '900576548' from dual union
    select '900555518' from dual union
    select '900331536' from dual union
    select '900637351' from dual union
    select '900578227' from dual union
    select '900638060' from dual union
    select '900511109' from dual union
    select '900434017' from dual union
    select '900565940' from dual union
    select '900210327' from dual union
    select '900652811' from dual union
    select '900160404' from dual union
    select '900480252' from dual union
    select '900230710' from dual union
    select '900245934' from dual union
    select '900653551' from dual union
    select '900651377' from dual union
    select '900611340' from dual union
    select '900654411' from dual union
    select '900655474' from dual union
    select '900645884' from dual union
    select '900316681' from dual union
    select '900455724' from dual union
    select '900653908' from dual union
    select '900202485' from dual union
    select '900240166' from dual union
    select '900008864' from dual union
    select '900319842' from dual union
    select '900653087' from dual union
    select '900514573' from dual union
    select '900653238' from dual union
    select '900655687' from dual union
    select '900333363' from dual union
    select '900653032' from dual union
    select '900491214' from dual union
    select '900246492' from dual union
    select '900354692' from dual union
    select '900654923' from dual union
    select '900568730' from dual union
    select '900546338' from dual union
    select '900535376' from dual union
    select '900653049' from dual union
    select '900298808' from dual union
    select '900633687' from dual union
    select '900653173' from dual union
    select '900624438' from dual union
    select '900479245' from dual union
    select '900606274' from dual union
    select '900619128' from dual union
    select '900606951' from dual union
    select '900197305' from dual union
    select '900101195' from dual union
    select '900525841' from dual union
    select '900654284' from dual union
    select '900579187' from dual union
    select '900654909' from dual union
    select '900646878' from dual union
    select '900249907' from dual union
    select '900595239' from dual union
    select '900013363' from dual union
    select '900347438' from dual union
    select '900569841' from dual union
    select '900655508' from dual union
    select '900655034' from dual union
    select '900654277' from dual union
    select '900295434' from dual union
    select '900624744' from dual union
    select '900609002' from dual union
    select '900612035' from dual union
    select '900651494' from dual union
    select '900223721' from dual union
    select '900269022' from dual union
    select '900583551' from dual union
    select '900562930' from dual union
    select '900449468' from dual union
    select '900488298' from dual union
    select '900655450' from dual union
    select '900380303' from dual union
    select '900522642' from dual union
    select '900477009' from dual union
    select '900592528' from dual union
    select '900389034' from dual union
    select '900577006' from dual union
    select '900613380' from dual union
    select '900608544' from dual union
    select '900579297' from dual union
    select '900617339' from dual union
    select '900583867' from dual union
    select '900145274' from dual union
    select '900602658' from dual union
    select '900610679' from dual union
    select '900021889' from dual union
    select '900398135' from dual union
    select '900594599' from dual union
    select '900634217' from dual union
    select '900211005' from dual union
    select '900592212' from dual union
    select '900508365' from dual union
    select '900570944' from dual union
    select '900620551' from dual union
    select '900606092' from dual union
    select '900325005' from dual union
    select '900643679' from dual union
    select '900647415' from dual union
    select '900543579' from dual union
    select '900565438' from dual union
    select '900586475' from dual union
    select '900545887' from dual union
    select '900548512' from dual union
    select '900651535' from dual union
    select '900542516' from dual union
    select '900140262' from dual union
    select '900536676' from dual union
    select '900651652' from dual union
    select '900652763' from dual union
    select '900652770' from dual union
    select '900599147' from dual union
    select '900466858' from dual union
    select '900596168' from dual union
    select '900597121' from dual union
    select '900549939' from dual union
    select '900505386' from dual union
    select '900349289' from dual union
    select '900195468' from dual union
    select '900358005' from dual union
    select '900655278' from dual union
    select '900550702' from dual union
    select '900652402' from dual union
    select '900376018' from dual union
    select '900652990' from dual union
    select '900685880' from dual union
    select '900635421' from dual union
    select '900619317' from dual union
    select '900654916' from dual union
    select '900652859' from dual union
    select '900653094' from dual union
    select '900576146' from dual union
    select '900591905' from dual union
    select '900290446' from dual union
    select '900565847' from dual union
    select '900544855' from dual union
    select '900612059' from dual union
    select '900616912' from dual union
    select '900535297' from dual union
    select '900610655' from dual union
    select '900585618' from dual union
    select '900625604' from dual union
    select '900634956' from dual union
    select '900620946' from dual union
    select '900561915' from dual union
    select '900479317' from dual union
    select '900572575' from dual union
    select '900500123' from dual union
    select '900537048' from dual union
    select '900516654' from dual union
    select '900530357' from dual union
    select '900621370' from dual union
    select '900510603' from dual union
    select '900641127' from dual union
    select '900432345' from dual union
    select '900628580' from dual union
    select '900154148' from dual union
    select '900615894' from dual union
    select '900615904' from dual union
    select '900071641' from dual union
    select '900638101' from dual union
    select '900233579' from dual union
    select '900550829' from dual union
    select '900575255' from dual union
    select '900008039' from dual union
    select '900542011' from dual union
    select '900654442' from dual union
    select '900361461' from dual union
    select '900240001' from dual union
    select '900399710' from dual union
    select '900549245' from dual union
    select '900560907' from dual union
    select '900479166' from dual union
    select '900516472' from dual union
    select '900654428' from dual union
    select '900572135' from dual union
    select '900572221' from dual union
    select '900589186' from dual union
    select '900591596' from dual union
    select '900653829' from dual union
    select '900309018' from dual union
    select '900620733' from dual union
    select '900109148' from dual union
    select '900655560' from dual union
    select '900144039' from dual union
    select '900450808' from dual union
    select '900156504' from dual union
    select '900655106' from dual union
    select '900312890' from dual union
    select '900653757' from dual union
    select '900653764' from dual union
    select '900655371' from dual union
    select '900592786' from dual union
    select '900558047' from dual union
    select '900467536' from dual union
    select '900654459' from dual union
    select '900654703' from dual union
    select '900155008' from dual union
    select '900586585' from dual union
    select '900488085' from dual union
    select '900583245' from dual union
    select '900223367' from dual union
    select '900597781' from dual union
    select '900655254' from dual union
    select '900616187' from dual union
    select '900043676' from dual union
    select '900538764' from dual union
    select '900582983' from dual union
    select '900481947' from dual union
    select '900603886' from dual union
    select '900569573' from dual union
    select '900464234' from dual union
    select '900655656' from dual union
    select '900171545' from dual union
    select '900634891' from dual union
    select '900476091' from dual union
    select '900504639' from dual union
    select '900653221' from dual union
    select '900575042' from dual union
    select '900294464' from dual union
    select '900653575' from dual union
    select '900121533' from dual union
    select '900056655' from dual union
    select '900428892' from dual union
    select '900184578' from dual union
    select '900607749' from dual union
    select '900229552' from dual union
    select '900599226' from dual union
    select '900573246' from dual union
    select '900600168' from dual union
    select '900501832' from dual union
    select '900479953' from dual union
    select '900424898' from dual union
    select '900598696' from dual union
    select '900634028' from dual union
    select '900390151' from dual union
    select '900268344' from dual union
    select '900654758' from dual union
    select '900174029' from dual union
    select '900644553' from dual union
    select '900107184' from dual union
    select '900251702' from dual union
    select '900387977' from dual union
    select '900206922' from dual union
    select '900654789' from dual union
    select '900654796' from dual union
    select '900623248' from dual union
    select '900654741' from dual union
    select '900369005' from dual union
    select '900195499' from dual union
    select '900560804' from dual union
    select '900006800' from dual union
    select '900233146' from dual union
    select '900550599' from dual union
    select '900375323' from dual union
    select '900508516' from dual union
    select '900608568' from dual union
    select '900652952' from dual union
    select '900655333' from dual union
    select '900655340' from dual union
    select '900655357' from dual union
    select '900655364' from dual union
    select '900654208' from dual union
    select '900567849' from dual union
    select '900567801' from dual union
    select '900617913' from dual union
    select '900653685' from dual union
    select '900570683' from dual union
    select '900530010' from dual union
    select '900329243' from dual union
    select '900518498' from dual union
    select '900645554' from dual union
    select '900443503' from dual union
    select '900598366' from dual union
    select '900257351' from dual union
    select '900634839' from dual union
    select '900336744' from dual union
    select '900332788' from dual union
    select '900417469' from dual union
    select '900504433' from dual union
    select '900130476' from dual union
    select '900141256' from dual union
    select '900376984' from dual union
    select '900502486' from dual union
    select '900576397' from dual union
    select '900333198' from dual union
    select '900575750' from dual union
    select '900649974' from dual union
    select '900653025' from dual union
    select '900653214' from dual union
    select '900655285' from dual union
    select '900630725' from dual union
    select '900026781' from dual union
    select '900309506' from dual union
    select '900507467' from dual union
    select '900475416' from dual union
    select '900601279' from dual union
    select '900540868' from dual union
    select '900516197' from dual union
    select '900655443' from dual union
    select '900512904' from dual union
    select '900654545' from dual union
    select '900611041' from dual union
    select '900653616' from dual union
    select '900654435' from dual union
    select '900559457' from dual union
    select '900559543' from dual union
    select '900405406' from dual union
    select '900408856' from dual union
    select '900561726' from dual union
    select '900624397' from dual union
    select '900522068' from dual union
    select '900581724' from dual union
    select '900043762' from dual union
    select '900357695' from dual union
    select '900648258' from dual union
    select '900654765' from dual union
    select '900543074' from dual union
    select '900049989' from dual union
    select '900147128' from dual union
    select '900653142' from dual union
    select '900540071' from dual union
    select '900587043' from dual union
    select '900655247' from dual union
    select '900654370' from dual union
    select '900655601' from dual union
    select '900426223' from dual union
    select '900654538' from dual union
    select '900629598' from dual union
    select '900653070' from dual union
    select '900655137' from dual union
    select '900572733' from dual union
    select '900592762' from dual union
    select '900655144' from dual union
    select '900651315' from dual union
    select '900653609' from dual union
    select '900380808' from dual union
    select '900554964' from dual union
    select '900653207' from dual union
    select '900653623' from dual union
    select '900625790' from dual union
    select '900627046' from dual union
    select '900603037' from dual union
    select '900653269' from dual union
    select '900533051' from dual union
    select '900652842' from dual union
    select '900456684' from dual union
    select '900653434' from dual union
    select '900549575' from dual union
    select '900563845' from dual union
    select '900553554' from dual union
    select '900654466' from dual union
    select '900483509' from dual union
    select '900199125' from dual union
    select '900315556' from dual union
    select '900655010' from dual union
    select '900426979' from dual union
    select '900655539' from dual union
    select '900654239' from dual union
    select '900193002' from dual union
    select '900591699' from dual union
    select '900291069' from dual union
    select '900363731' from dual union
    select '900226834' from dual union
    select '900067521' from dual union
    select '900035569' from dual union
    select '900654569' from dual union
    select '900195798' from dual union
    select '900555824' from dual union
    select '900114829' from dual union
    select '900301371' from dual union
    select '900296710' from dual union
    select '900507625' from dual union
    select '900655151' from dual union
    select '900639267' from dual union
    select '900053999' from dual union
    select '900235100' from dual union
    select '900401220' from dual union
    select '900655216' from dual union
    select '900557400' from dual union
    select '900272419' from dual union
    select '900533776' from dual union
    select '900536559' from dual union
    select '900283282' from dual union
    select '900620087' from dual union
    select '900345151' from dual union
    select '900341858' from dual union
    select '900414057' from dual union
    select '900548392' from dual union
    select '900068656' from dual union
    select '900402692' from dual union
    select '900508891' from dual union
    select '900533518' from dual union
    select '900280492' from dual union
    select '900138151' from dual union
    select '900105560' from dual union
    select '900106169' from dual union
    select '900097614' from dual union
    select '900633089' from dual union
    select '900396717' from dual union
    select '900653166' from dual union
    select '900133651' from dual union
    select '900653506' from dual union
    select '900586523' from dual union
    select '900306510' from dual union
    select '900603271' from dual union
    select '900654734' from dual union
    select '900610277' from dual union
    select '900651140' from dual union
    select '900582062' from dual union
    select '900640133' from dual union
    select '900637753' from dual union
    select '900582880' from dual union
    select '900588477' from dual union
    select '900539071' from dual union
    select '900580345' from dual union
    select '900653582' from dual union
    select '900451469' from dual union
    select '900543641' from dual union
    select '900606676' from dual union
    select '900216017' from dual union
    select '900653348' from dual union
    select '900583458' from dual union
    select '900654710' from dual union
    select '900647659' from dual union
    select '900652787' from dual union
    select '900652794' from dual union
    select '900219986' from dual union
    select '900654552' from dual union
    select '900647635' from dual union
    select '900470909' from dual union
    select '900169757' from dual union
    select '900431368' from dual union
    select '900616833' from dual union
    select '900653788' from dual union
    select '900686104' from dual union
    select '900640872' from dual union
    select '900300985' from dual union
    select '900614257' from dual union
    select '900622027' from dual union
    select '900046656' from dual union
    select '900101834' from dual union
    select '900599996' from dual union
    select '900418161' from dual union
    select '900618787' from dual union
    select '900653355' from dual union
    select '900653850' from dual union
    select '900654301' from dual union
    select '900643459' from dual union
    select '900056507' from dual union
    select '900599305' from dual union
    select '900655405' from dual union
    select '900539507' from dual union
    select '900652969' from dual union
    select '900652378' from dual union
    select '900238213' from dual union
    select '900426900' from dual union
    select '900083790' from dual union
    select '900473861' from dual union
    select '900591091' from dual union
    select '900583025' from dual union
    select '900498077' from dual union
    select '900649572' from dual union
    select '900655326' from dual union
    select '900533707' from dual union
    select '900645509' from dual union
    select '900554696' from dual union
    select '900604966' from dual union
    select '900653300' from dual union
    select '900653939' from dual union
    select '900653771' from dual union
    select '900625006' from dual union
    select '900593990' from dual union
    select '900348381' from dual union
    select '900649084' from dual union
    select '900633216' from dual union
    select '900652938' from dual union
    select '900654136' from dual union
    select '900414583' from dual union
    select '900654693' from dual union
    select '900620348' from dual union
    select '900548945' from dual union
    select '900571017' from dual union
    select '900621394' from dual union
    select '900543517' from dual union
    select '900623279' from dual union
    select '900649527' from dual union
    select '900574096' from dual union
    select '900502754' from dual union
    select '900006855' from dual union
    select '900385858' from dual union
    select '900569494' from dual union
    select '900640281' from dual union
    select '900654882' from dual union
    select '900533824' from dual union
    select '900616974' from dual union
    select '900413063' from dual union
    select '900653702' from dual union
    select '900652873' from dual union
    select '900595617' from dual union
    select '900640951' from dual union
    select '900537983' from dual union
    select '900624940' from dual union
    select '900653726' from dual union
    select '900614343' from dual union
    select '900654521' from dual union
    select '900653252' from dual union
    select '900653001' from dual union
    select '900028989' from dual union
    select '900646414' from dual union
    select '900054505' from dual union
    select '900637179' from dual union
    select '900653661' from dual union
    select '900652677' from dual union
    select '900654215' from dual union
    select '900619070' from dual union
    select '900063754' from dual union
    select '900450592' from dual union
    select '900541041' from dual union
    select '900652464' from dual union
    select '900654291' from dual union
    select '900618653' from dual union
    select '900625415' from dual union
    select '900515495' from dual union
    select '900652945' from dual union
    select '900539662' from dual union
    select '900655704' from dual union
    select '900402324' from dual union
    select '900655498' from dual union
    select '900489323' from dual union
    select '900639236' from dual union
    select '900617188' from dual union
    select '900319385' from dual union
    select '900612334' from dual union
    select '900588934' from dual union
    select '900578629' from dual union
    select '900636594' from dual union
    select '900504000' from dual union
    select '900576452' from dual union
    select '900640786' from dual union
    select '900522604' from dual union
    select '900210822' from dual union
    select '900087581' from dual union
    select '900618282' from dual union
    select '900521610' from dual union
    select '900557668' from dual union
    select '900526842' from dual union
    select '900637241' from dual union
    select '900607646' from dual union
    select '900651449' from dual union
    select '900637272' from dual union
    select '900486083' from dual union
    select '900652103' from dual union
    select '900654772' from dual union
    select '900608537' from dual union
    select '900506600' from dual union
    select '900544745' from dual union
    select '900622869' from dual union
    select '900631757' from dual union
    select '900552041' from dual union
    select '900654026' from dual union
    select '900653018' from dual union
    select '900622508' from dual union
    select '900652835' from dual union
    select '900595734' from dual union
    select '900531846' from dual union
    select '900655577' from dual union
    select '900559598' from dual union
    select '900651085' from dual union
    select '900314562' from dual union
    select '900653843' from dual union
    select '900513596' from dual union
    select '900556454' from dual union
    select '900185902' from dual union
    select '900582873' from dual union
    select '900649060' from dual union
    select '900295874' from dual union
    select '900655481' from dual union
    select '900190968' from dual union
    select '900647130' from dual union
    select '900292077' from dual union
    select '900307858' from dual union
    select '900535819' from dual union
    select '900531547' from dual union
    select '900654071' from dual union
    select '900071263' from dual union
    select '900653290' from dual union
    select '900655027' from dual union
    select '900613036' from dual union
    select '900010810' from dual union
    select '900654590' from dual union
    select '900362761' from dual union
    select '900043449' from dual union
    select '900654583' from dual union
    select '900612640' from dual union
    select '900542932' from dual union
    select '900655120' from dual union
    select '900653630' from dual union
    select '900655625' from dual union
    select '900650273' from dual union
    select '900653647' from dual union
    select '900654088' from dual union
    select '900591613' from dual union
    select '900569724' from dual union
    select '900653331' from dual union
    select '900436253' from dual union
    select '900654820' from dual union
    select '900654002' from dual union
    select '900654514' from dual union
    select '900421125' from dual union
    select '900652048' from dual union
    select '900615540' from dual union
    select '900653898' from dual union
    select '900654806' from dual union
    select '900631616' from dual union
    select '900330937' from dual union
    select '900653733' from dual union
    select '900194625' from dual union
    select '900654576' from dual union
    select '900654930' from dual union
    select '900433504' from dual union
    select '900387379' from dual union
    select '900482948' from dual union
    select '900278570' from dual union
    select '900610727' from dual union
    select '900558968' from dual union
    select '900584978' from dual union
    select '900162932' from dual union
    select '900347050' from dual union
    select '900654978' from dual union
    select '900438389' from dual union
    select '900538142' from dual union
    select '900654473' from dual union
    select '900605228' from dual union
    select '900599721' from dual union
    select '900650699' from dual union
    select '900648461' from dual union
    select '900622890' from dual union
    select '900500879' from dual union
    select '900597035' from dual union
    select '900645097' from dual union
    select '900251685' from dual union
    select '900653812' from dual union
    select '900655261' from dual union
    select '900650613' from dual union
    select '900653654' from dual union
    select '900510768' from dual union
    select '900653410' from dual union
    select '900118218' from dual union
    select '900309269' from dual union
    select '900653441' from dual union
    select '900654325' from dual union
    select '900652495' from dual union
    select '900489990' from dual union
    select '900421792' from dual union
    select '900653599' from dual union
    select '900622955' from dual union
    select '900651542' from dual union
    select '900013208' from dual union
    select '900574591' from dual union
    select '900562277' from dual union
    select '900622924' from dual union
    select '900652622' from dual union
    select '900653740' from dual union
    select '900650565' from dual union
    select '900537268' from dual union
    select '900651566' from dual union
    select '900630907' from dual union
    select '900596151' from dual union
    select '900654332' from dual union
    select '900639810' from dual union
    select '900653568' from dual union
    select '900654246' from dual union
    select '900032432' from dual union
    select '900276750' from dual union
    select '900301436' from dual union
    select '900625989' from dual union
    select '900485161' from dual union
    select '900123614' from dual union
    select '900550685' from dual union
    select '900376726' from dual union
    select '900152043' from dual union
    select '900654404' from dual union
    select '900653946' from dual union
    select '900654947' from dual union
    select '900512698' from dual union
    select '900201817' from dual union
    select '900524352' from dual union
    select '900624421' from dual union
    select '900095502' from dual union
    select '900400195' from dual union
    select '900653881' from dual union
    select '900651339' from dual union
    select '900553365' from dual union
    select '900617449' from dual union
    select '900473971' from dual union
    select '900070657' from dual union
    select '900254949' from dual union
    select '900626973' from dual union
    select '900447394' from dual union
    select '900373716' from dual union
    select '900655694' from dual union
    select '900179622' from dual union
    select '900413245' from dual union
    select '900529412' from dual union
    select '900279540' from dual union
    select '900561472' from dual union
    select '900586688' from dual union
    select '900647453' from dual union
    select '900652804' from dual union
    select '900647714' from dual union
    select '900233225' from dual union
    select '900484414' from dual union
    select '900619111' from dual union
    select '900613191' from dual union
    select '900190164' from dual union
    select '900653472' from dual union
    select '900252222' from dual union
    select '900473421' from dual union
    select '900655515' from dual union
    select '900654480' from dual union
    select '900652880' from dual union
    select '900021339' from dual union
    select '900655670' from dual union
    select '900653197' from dual union
    select '900646081' from dual union
    select '900400236' from dual union
    select '900045703' from dual union
    select '900653922' from dual union
    select '900654992' from dual union
    select '900524417' from dual union
    select '900631733' from dual union
    select '900230947' from dual union
    select '900413434' from dual union
    select '900654040' from dual union
    select '900652505' from dual union
    select '900478684' from dual union
    select '900547920' from dual union
    select '900654363' from dual union
    select '900142752' from dual union
    select '900588783' from dual union
    select '900652660' from dual union
    select '900653317' from dual union
    select '900562260' from dual union
    select '900624005' from dual union
    select '900523832' from dual union
    select '900631506' from dual union
    select '900043638' from dual union
    select '900648382' from dual union
    select '900652093' from dual union
    select '900551253' from dual union
    select '900654174' from dual union
    select '900472822' from dual union
    select '900549568' from dual union
    select '900175680' from dual union
    select '900647707' from dual union
    select '900553547' from dual union
    select '900241480' from dual union
    select '900243949' from dual union
    select '900628731' from dual union
    select '900413647' from dual union
    select '900655096' from dual union
    select '900654985' from dual union
    select '900253656' from dual union
    select '900200249' from dual union
    select '900380523' from dual union
    select '900655302' from dual union
    select '900654954' from dual union
    select '900651102' from dual union
    select '900437450' from dual union
    select '900162860' from dual union
    select '900212453' from dual union
    select '900524967' from dual union
    select '900396432' from dual union
    select '900652921' from dual union
    select '900079687' from dual union
    select '900654181' from dual union
    select '900655223' from dual union
    select '900654868' from dual union
    select '900587153' from dual union
    select '900694857' from dual union
    select '900505616' from dual union
    select '900558827' from dual union
    select '900654507' from dual union
    select '900653867' from dual union
    select '900004152' from dual union
    select '900652866' from dual union
    select '900199118' from dual union
    select '900376317' from dual union
    select '900477298' from dual union
    select '900407594' from dual union
    select '900655292' from dual union
    select '900204889' from dual union
    select '900003450' from dual union
    select '900565995' from dual union
    select '900258273' from dual union
    select '900579084' from dual union
    select '900650864' from dual union
    select '900653953' from dual union
    select '900056404' from dual union
    select '900582691' from dual union
    select '900470040' from dual union
    select '900655182' from dual union
    select '900655591' from dual union
    select '900643428' from dual union
    select '900655388' from dual union
    select '900655395' from dual union
    select '900654349' from dual union
    select '900547188' from dual union
    select '900654260' from dual union
    select '900611467' from dual union
    select '900618897' from dual union
    select '900654686' from dual union
    select '900651645' from dual union
    select '900032724' from dual union
    select '900503250' from dual union
    select '900605022' from dual union
    select '900594850' from dual union
    select '900603240' from dual union
    select '900619630' from dual union
    select '900533123' from dual union
    select '900654837' from dual union
    select '900654844' from dual union
    select '900572214' from dual union
    select '900653465' from dual union
    select '900629055' from dual union
    select '900654727' from dual union
    select '900570085' from dual union
    select '900655089' from dual union
    select '900654813' from dual union
    select '900513321' from dual union
    select '900653991' from dual union
    select '900654600' from dual union
    select '900488119' from dual union
    select '900616682' from dual union
    select '900529003' from dual union
    select '900654057' from dual union
    select '900616039' from dual union
    select '900431980' from dual union
    select '900655319' from dual union
    select '900518072' from dual union
    select '900654129' from dual union
    select '900655041' from dual union
    select '900645743' from dual union
    select '900467574' from dual union
    select '900650895' from dual union
    select '900501399' from dual union
    select '900655113' from dual union
    select '900581449' from dual union
    select '900636264' from dual union
    select '900221808' from dual union
    select '900654851' from dual union
    select '900654679' from dual union
    select '900653520' from dual union
    select '900653537' from dual union
    select '900652983' from dual union
    select '900618529' from dual union
    select '900646005' from dual union
    select '900546871' from dual union
    select '900649651' from dual union
    select '900572678' from dual union
    select '900194412' from dual union
    select '900395156' from dual union
    select '900651164' from dual union
    select '900654662' from dual union
    select '900633209' from dual union
    select '900580761' from dual union
    select '900654105' from dual union
    select '900598689' from dual union
    select '900655199' from dual union
    select '900655003' from dual union
    select '900653283' from dual union
    select '900564671' from dual union
    select '900652897' from dual union
    select '900547793' from dual union
    select '900637124' from dual union
    select '900394306' from dual union
    select '900611508' from dual union
    select '900651944' from dual union
    select '900518560' from dual union
    select '900650761' from dual) x
    WHERE NOT EXISTS (SELECT 1 FROM cc_lin_sobregiros c WHERE c.nro_cuenta = x.nro_cuenta);
    
  --Historico de lineas de sobregiros x Cuenta
  cursor cur_his_det is
    select x.nro_sec_padre, x.estado, x.can_automatica, x.monto, x.rowid
      from cc_lin_sobregiros_his x
     where x.nro_cuenta = v_nro_cuenta
     order by x.fec_insercion desc;

function lf_obt_lin_sobregiro(p_nro_cuenta varchar2,
                              p_tipo       varchar2)
  return varchar2 is
  v_existe varchar2(1):= 'N';
begin
  begin
    select distinct 'S'
      into v_existe
      from cc_lin_sobregiros
     where nro_cuenta = p_nro_cuenta
       and tipo       = p_tipo;
  exception
    when no_data_found then
      v_existe := 'N';
    when others then
      v_existe := 'S';
  end;
  return v_existe;
end;

BEGIN
  pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1;  
  
  if cur_his_det%isopen then
    close cur_his_det;
  end if;

  v_observacion := '* '||to_char(v_fec_actual,'dd/mm/yyyy')||' - Línea Reactivada';

  for k in cur_cte loop
    v_insertar   := 'S';
    v_nro_cuenta := k.nro_cuenta;
    open cur_his_det;
    fetch cur_his_det
      into v_nro_sec_padre_his,v_estado,v_can_automatica,v_monto_det,v_rowid_det;

    if cur_his_det%found THEN
      --Si el ultimo estado en el Historico es Cancelado 
      if v_estado IN ('V','C') then
        begin
          --Recuperar rowid de registro Cabecera
          select rowid, x.monto, x.tipo
            into v_rowid_cab, v_monto_cab, v_tipo
            from cc_lin_sobregiros_his x
           where x.nro_secuencia = v_nro_sec_padre_his
             and x.fec_insercion =(select max(fec_insercion)
                                     from cc_lin_sobregiros_his j
                                    where j.nro_secuencia = v_nro_sec_padre_his);             
            
          if v_monto_det > v_monto_cab THEN
            
            v_insertar := 'N';
          end if;
        exception
          when others then
             v_insertar := 'N'; --No se encontro el registro o esta duplicado
        end;
        
        --Verificar que no exista una línea p/ la cuenta
        if lf_obt_lin_sobregiro(k.nro_cuenta,v_tipo) = 'S' THEN  
           v_insertar := 'N';
        end if;

        if v_insertar = 'S' THEN
          --Generar Nuevo Nro. de Secuencia Padre
          select s_nro_lin_sobregiro.nextval into v_nro_sec_padre from dual;

          --Insertar Registro Cabecera
          insert into cc_lin_sobregiros
           (nro_cuenta, fec_vencimiento, fec_inicio, nro_secuencia, monto, tipo, cod_persona, cod_moneda, estado, nro_sec_padre, observacion, niv_aprobacion)
          select null, v_fec_vencimiento, v_fec_actual, v_nro_sec_padre, x.monto, x.tipo, x.cod_persona, x.cod_moneda, 'A', null, v_observacion, x.niv_aprobacion
            from cc_lin_sobregiros_his x
           where x.rowid = v_rowid_cab;

          --Generar Nuevo Nro. de Secuencia
          select s_nro_lin_sobregiro.nextval into v_nro_secuencia from dual;

          --Insertar Registro Detalle
          insert into cc_lin_sobregiros
           (nro_cuenta, fec_vencimiento, fec_inicio, nro_secuencia, monto, tipo, cod_persona, cod_moneda, estado, nro_sec_padre, observacion, niv_aprobacion)
          select x.nro_cuenta, v_fec_vencimiento, v_fec_actual, v_nro_secuencia, x.monto, x.tipo, null, x.cod_moneda, 'A', v_nro_sec_padre, v_observacion, x.niv_aprobacion
            from cc_lin_sobregiros_his x
           where x.rowid = v_rowid_det;

          --Insertar Registro Garantia
          insert into cc_lin_sob_garantias
            (mto_aplicado, nro_secuencia, cod_garantia)
          values
            (v_monto_cab, v_nro_sec_padre, 1);

          --Actualizar CC_CTA_CORRIENTES
          update cc_cta_corrientes c
             set c.acu_sobregiro = 'S'
           where c.nro_cuenta = v_nro_cuenta;
        end if;
      end if;
    end if;
    close cur_his_det;
  end loop;
  
  COMMIT;

exception
  when others then
    if sqlcode <= -20000 then
      raise;
    else
      raise_application_error(-20000,
                              'PRC_ACT_LIN_SOB_SUELDOS: Cta.: ' ||
                              v_nro_cuenta || '; Sec.: ' || v_nro_sec_padre || '.' ||
                              SQLERRM);
    end if;
END;
